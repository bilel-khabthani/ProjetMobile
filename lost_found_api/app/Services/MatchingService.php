<?php

namespace App\Services;

use App\Models\Item;
use App\Models\ItemMatch;

/**
 * Module 3 - Moteur de matching (CDC sections 6.3 et 8.4).
 *
 * Note importante sur l'IA : le CDC demande un scoring multi-criteres. Pour la
 * demo, le scoring est realise par des regles deterministes et explicites
 * (poids, distance Haversine, similarite de texte, ecart temporel). Aucun
 * appel reseau ni modele externe n'est requis, ce qui garantit un resultat
 * reproductible et instantane. Le contrat de sortie (4 dimensions + score
 * global + decision) est deja compatible avec le remplacement du calcul par un
 * vrai modele sans toucher au frontend.
 */
class MatchingService
{
    /**
     * Poids par dimension (CDC 6.3.2). En demo l'image n'est pas exploitable,
     * la cle 'image' est donc absente de cette table et son poids est redistribue
     * aux dimensions reellement calculees. Les poids restants sont renormalises,
     * ce qui evite de fausser la moyenne avec une dimension neutre.
     */
    private const WEIGHTS = [
        'location' => 50,
        'time' => 30,
        'text' => 20,
    ];

    /** Au-dela de ce score global, le systeme ne propose pas la correspondance. */
    private const MIN_GLOBAL_SCORE = 60;

    /** Distance au-dela de laquelle la dimension localisation vaut 0. */
    private const MAX_RELEVANT_DISTANCE_KM = 50;

    public function score(Item $lost, Item $found): array
    {
        $dimensions = [
            'image_score' => 100,
            'location_score' => $this->locationScore($lost, $found),
            'time_score' => $this->timeScore($lost, $found),
            'text_score' => $this->textScore($lost, $found),
        ];

        // Moyenne ponderee normalisee sur les seules dimensions calculees :
        // la somme des poids actually utilises vaut toujours 100.
        $global = 0;
        foreach (self::WEIGHTS as $dimension => $weight) {
            $global += $dimensions[$dimension.'_score'] * $weight / 100;
        }

        // Le type doit rester oppose : un objet perdu ne correspond jamais
        // a un autre objet perdu. C'est un garde-fou, pas un score.
        $global = $lost->type === $found->type ? 0 : (int) round($global);

        $decision = match (true) {
            $global >= 80 => 'YES',
            $global >= self::MIN_GLOBAL_SCORE => 'UNSURE',
            default => 'NO',
        };

        return [
            'dimensions' => $dimensions,
            'global_score' => $global,
            'decision' => $decision,
        ];
    }

    /**
     * Genere les correspondances candidates pour un objet donne et les persiste.
     * Les candidats sont tries par score decroissant (CDC 6.3.3).
     */
    public function findMatches(Item $item): array
    {
        $oppositeType = $item->type === Item::TYPE_LOST ? Item::TYPE_FOUND : Item::TYPE_LOST;

        $candidates = Item::query()
            ->where('type', $oppositeType)
            ->where('status', 'ACTIVE')
            ->get();

        $results = [];

        foreach ($candidates as $candidate) {
            // Garde-fou STRICT anti auto-restitution (CDC 6.4.3) : on ne propose
            // jamais la correspondance d'un objet avec lui-meme. Le blocage est
            // applique ici, a la creation du match, et non seulement au moment
            // de la restitution, pour qu'aucun match invalide ne soit cree.
            if ($candidate->user_id === $item->user_id) {
                continue;
            }

            $scored = $this->score($item, $candidate);

            if ($scored['decision'] === 'NO') {
                continue;
            }

            $lost = $item->type === Item::TYPE_LOST ? $item : $candidate;
            $found = $item->type === Item::TYPE_LOST ? $candidate : $item;

            $results[] = [
                'match' => $this->persistMatch($lost, $found, $scored),
                'score' => $scored,
            ];
        }

        usort($results, fn ($a, $b) => $b['score']['global_score'] <=> $a['score']['global_score']);

        return $results;
    }

    /**
     * Persiste le score sans ecraser la reponse deja donnee par l'utilisateur.
     * "decision.engine" = verdict du moteur (re-evaluable a chaque passage),
     * "decision.answer" = reponse Oui/Incertain/Non du proprietaire (sacree,
     * ecrite par MatchController::answer et jamais recalculee).
     */
    private function persistMatch(Item $lost, Item $found, array $scored): ItemMatch
    {
        $existing = ItemMatch::query()
            ->where('lost_item_id', $lost->id)
            ->where('found_item_id', $found->id)
            ->first();

        $decision = array_merge($existing?->decision ?? [], ['engine' => $scored['decision']]);

        return ItemMatch::updateOrCreate(
            ['lost_item_id' => $lost->id, 'found_item_id' => $found->id],
            [
                ...$scored['dimensions'],
                'global_score' => $scored['global_score'],
                'decision' => $decision,
            ]
        );
    }

    /**
     * Localisation : plus deux objets sont proches, plus le score est eleve.
     * Sans coordonnees exploitables, on renvoie une valeur neutre pour ne pas
     * penaliser unfairement une declaration incomplete.
     */
    private function locationScore(Item $lost, Item $found): int
    {
        if ($lost->latitude === null || $found->latitude === null) {
            return 50;
        }

        $distance = $this->haversineKm(
            (float) $lost->latitude, (float) $lost->longitude,
            (float) $found->latitude, (float) $found->longitude
        );

        // Degradation lineaire : 100 a 0 km, 0 a MAX_RELEVANT_DISTANCE_KM.
        $ratio = 1 - min($distance, self::MAX_RELEVANT_DISTANCE_KM) / self::MAX_RELEVANT_DISTANCE_KM;

        return (int) round($ratio * 100);
    }

    /** Temps : un ecart faible indique une correspondance plausible. */
    private function timeScore(Item $lost, Item $found): int
    {
        $hours = abs($lost->occurred_at->diffInHours($found->occurred_at, false));

        if ($hours <= 12) {
            return 100;
        }

        if ($hours >= 24 * 14) {
            return 0;
        }

        // 100 au bout de 12 h, 0 au bout de 14 jours.
        return (int) round(100 * (1 - ($hours - 12) / (24 * 14 - 12)));
    }

    /**
     * Texte : comparaison par mots-cles normalises (minuscules, sans accents).
     * Le score est le taux de mots-cles du titre de l'objet perdu qui
     * apparaissent dans le titre, la description ou le lieu de l'objet trouve.
     */
    private function textScore(Item $lost, Item $found): int
    {
        $keywords = $this->keywords($lost->title.' '.$lost->description);

        if ($keywords === []) {
            return 50;
        }

        $haystack = $this->normalize($found->title.' '.$found->description.' '.$found->place_label);
        $hits = count(array_filter($keywords, fn ($word) => str_contains($haystack, $word)));

        return (int) round($hits / count($keywords) * 100);
    }

    /** Mots-cles retenus : on retire les mots vides et trop courts. */
    private function keywords(string $text): array
    {
        $normalized = $this->normalize($text);
        $words = preg_split('/[^a-z0-9]+/', $normalized) ?: [];

        $stopWords = [
            'un', 'une', 'des', 'de', 'du', 'la', 'le', 'les', 'et', 'ou', 'a', 'au', 'aux',
            'en', 'sur', 'pour', 'par', 'avec', 'mon', 'ma', 'mes', 'ce', 'cet', 'cette', 'est',
            'qui', 'que', 'dans', 'je', 'il', 'elle', 'very', 'the', 'and',
        ];

        $words = array_filter($words, fn ($word) => mb_strlen($word) > 2 && ! in_array($word, $stopWords, true));

        return array_values(array_unique($words));
    }

    /** Normalisation francaise : minuscules + suppression des accents. */
    private function normalize(string $text): string
    {
        $text = mb_strtolower(trim($text));
        $text = strtr($text, [
            'Ã ' => 'a', 'Ã¢' => 'a', 'Ã¤' => 'a', 'Ã¡' => 'a', 'Ã£' => 'a',
            'Ã§' => 'c',
            'Ã¨' => 'e', 'Ã©' => 'e', 'Ãª' => 'e', 'Ã«' => 'e',
            'Ã®' => 'i', 'Ã¯' => 'i', 'Ã­' => 'i',
            'Ã´' => 'o', 'Ã¶' => 'o', 'Ã³' => 'o', 'Ãµ' => 'o',
            'Ã¹' => 'u', 'Ã»' => 'u', 'Ã¼' => 'u', 'Ãº' => 'u',
            'Ã¿' => 'y',
            'Å“' => 'oe', 'Ã¦' => 'ae',
        ]);

        return preg_replace('/\s+/', ' ', $text) ?? $text;
    }

    /** Distance orthodromique entre deux points, formule de Haversine. */
    private function haversineKm(float $lat1, float $lon1, float $lat2, float $lon2): float
    {
        $earthRadius = 6371;

        $deltaLat = deg2rad($lat2 - $lat1);
        $deltaLon = deg2rad($lon2 - $lon1);

        $a = sin($deltaLat / 2) ** 2
            + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($deltaLon / 2) ** 2;

        return $earthRadius * 2 * atan2(sqrt($a), sqrt(1 - $a));
    }
}
