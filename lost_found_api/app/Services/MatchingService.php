<?php

namespace App\Services;

use App\Models\Item;
use App\Models\ItemMatch;
use Illuminate\Support\Str;

/**
 * Module 3 - Moteur de matching (CDC sections 6.3 et 8.4).
 *
 * Le score combine quatre signaux verifiables :
 *  - photo : empreinte perceptuelle (dHash 64 bits) calculee avec GD ;
 *  - localisation : distance Haversine entre les deux points ;
 *  - temps : ecart entre les dates de declaration ;
 *  - texte : mots-cles normalises + coherence de categorie.
 *
 * Le calcul reste deterministe et ne depend d'aucun service externe, mais il
 * exploite desormais reellement la photo quand elle est disponible.
 */
class MatchingService
{
    /** Poids par dimension (CDC 6.3.2), somme = 100. */
    private const WEIGHTS = [
        'image' => 30,
        'location' => 30,
        'time' => 15,
        'text' => 25,
    ];

    /** Au-dela de ce score global, le systeme propose la correspondance. */
    private const MIN_GLOBAL_SCORE = 60;

    private const YES_SCORE = 78;

    /** Distance au-dela de laquelle la dimension localisation vaut 0. */
    private const MAX_RELEVANT_DISTANCE_KM = 50;

    /**
     * Cache local des empreintes d'images pour ne pas relire le disque
     * plusieurs fois pendant un meme calcul de deck.
     *
     * @var array<string, int|null>
     */
    private array $imageHashes = [];

    /**
     * @return array{dimensions: array<string, int>, global_score: int, decision: string}
     */
    public function score(Item $lost, Item $found): array
    {
        $dimensions = [
            'image_score' => $this->imageScore($lost, $found),
            'location_score' => $this->locationScore($lost, $found),
            'time_score' => $this->timeScore($lost, $found),
            'text_score' => $this->textScore($lost, $found),
        ];

        $global = 0;
        foreach (self::WEIGHTS as $dimension => $weight) {
            $global += $dimensions[$dimension.'_score'] * $weight / 100;
        }

        // Garde-fous : un objet ne correspond jamais a lui-meme ni a une
        // declaration du meme utilisateur (CDC 6.4.3, anti auto-restitution).
        if ($lost->type === $found->type || $lost->user_id === $found->user_id) {
            $global = 0;
        } elseif ($lost->category !== $found->category) {
            // Une categorie differente reste possible mais ne doit pas produire
            // un faux "match fort" : on penalise lourdement le score.
            $global *= 0.55;
        }

        $global = (int) round(max(0, min(100, $global)));

        $decision = match (true) {
            $global >= self::YES_SCORE => 'YES',
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
     *
     * @return array<int, array{match: ItemMatch, score: array<string, mixed>}>
     */
    public function findMatches(Item $item): array
    {
        $oppositeType = $item->type === Item::TYPE_LOST ? Item::TYPE_FOUND : Item::TYPE_LOST;

        $candidates = Item::query()
            ->where('type', $oppositeType)
            ->where('status', 'ACTIVE')
            ->where('user_id', '!=', $item->user_id)
            ->get();

        $results = [];
        $validMatchIds = [];

        foreach ($candidates as $candidate) {
            $scored = $this->score($item, $candidate);

            if ($scored['decision'] === 'NO') {
                continue;
            }

            $lost = $item->type === Item::TYPE_LOST ? $item : $candidate;
            $found = $item->type === Item::TYPE_LOST ? $candidate : $item;

            $match = $this->persistMatch($lost, $found, $scored);
            $validMatchIds[] = $match->id;

            $results[] = [
                'match' => $match,
                'score' => $scored,
            ];
        }

        $this->removeStaleMatches($item, $validMatchIds);

        usort($results, fn ($a, $b) => $b['score']['global_score'] <=> $a['score']['global_score']);

        return $results;
    }

    /**
     * Persiste le score sans ecraser la reponse deja donnee par l'utilisateur.
     * "decision.engine" = verdict du moteur (re-evaluable a chaque passage),
     * "decision.answer" = reponse Oui/Incertain/Non du proprietaire, qui ne
     * doit jamais etre recalculee.
     *
     * @param  array{dimensions: array<string, int>, global_score: int, decision: string}  $scored
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
     * Supprime les anciennes propositions du moteur qui ne correspondent plus.
     * Les correspondances ayant deja une reponse utilisateur sont conservees.
     *
     * @param  array<int, string>  $validMatchIds
     */
    private function removeStaleMatches(Item $item, array $validMatchIds): void
    {
        ItemMatch::query()
            ->where(fn ($query) => $query
                ->where('lost_item_id', $item->id)
                ->orWhere('found_item_id', $item->id))
            ->where('status', ItemMatch::STATUS_PENDING)
            ->when($validMatchIds !== [], fn ($query) => $query->whereNotIn('id', $validMatchIds))
            ->get()
            ->each(function (ItemMatch $match): void {
                if (! isset($match->decision['answer'])) {
                    $match->delete();
                }
            });
    }

    /**
     * Similarite visuelle : dHash 8x8 (difference de luminosite entre pixels
     * voisins). Deux photos identiques ont une distance de Hamming de 0.
     * Sans photo exploitable, la dimension reste neutre (50).
     */
    private function imageScore(Item $lost, Item $found): int
    {
        $left = $this->imageHash($lost->image_path);
        $right = $this->imageHash($found->image_path);

        if ($left === null || $right === null) {
            return 50;
        }

        $xor = $left ^ $right;
        $distance = 0;

        while ($xor !== 0) {
            $distance += $xor & 1;
            $xor >>= 1;
        }

        // 0 bit different = 100 %, 32 bits differents = 0 %.
        return (int) round(max(0, 1 - $distance / 32) * 100);
    }

    private function imageHash(?string $path): ?int
    {
        if ($path === null || trim($path) === '') {
            return null;
        }

        $fullPath = storage_path('app/public/'.ltrim($path, '/'));

        if (! is_file($fullPath)) {
            return null;
        }

        $cacheKey = $fullPath.'|'.(string) filemtime($fullPath);

        if (array_key_exists($cacheKey, $this->imageHashes)) {
            return $this->imageHashes[$cacheKey];
        }

        $contents = @file_get_contents($fullPath);

        if ($contents === false) {
            return $this->imageHashes[$cacheKey] = null;
        }

        $image = @imagecreatefromstring($contents);

        if ($image === false) {
            return $this->imageHashes[$cacheKey] = null;
        }

        $scaled = imagescale($image, 9, 8);
        imagedestroy($image);

        if ($scaled === false) {
            return $this->imageHashes[$cacheKey] = null;
        }

        $hash = 0;
        $bit = 0;

        for ($y = 0; $y < 8; $y++) {
            for ($x = 0; $x < 8; $x++) {
                $left = $this->luminance($scaled, $x, $y);
                $right = $this->luminance($scaled, $x + 1, $y);

                if ($left > $right) {
                    $hash |= (1 << $bit);
                }

                $bit++;
            }
        }

        imagedestroy($scaled);

        return $this->imageHashes[$cacheKey] = $hash;
    }

    private function luminance(\GdImage $image, int $x, int $y): float
    {
        $color = imagecolorsforindex($image, imagecolorat($image, $x, $y));

        return $color['red'] * 0.299 + $color['green'] * 0.587 + $color['blue'] * 0.114;
    }

    /**
     * Localisation : plus deux objets sont proches, plus le score est eleve.
     * Sans coordonnees exploitables, on renvoie une valeur neutre pour ne pas
     * penaliser unfairement une declaration incomplete.
     */
    private function locationScore(Item $lost, Item $found): int
    {
        if ($lost->latitude === null || $found->latitude === null
            || $lost->longitude === null || $found->longitude === null) {
            return 50;
        }

        $distance = $this->haversineKm(
            (float) $lost->latitude, (float) $lost->longitude,
            (float) $found->latitude, (float) $found->longitude
        );

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
     * Texte : mots-cles normalises + coherence de categorie. Le score de
     * mots-cles est le taux de mots significatifs de l'objet perdu retrouves
     * dans l'objet trouve.
     */
    private function textScore(Item $lost, Item $found): int
    {
        $keywords = $this->keywords($lost->title.' '.$lost->description);

        $keywordScore = 50;

        if ($keywords !== []) {
            $haystack = $this->normalize(
                $found->title.' '.$found->description.' '.$found->place_label.' '.$found->category
            );
            $hits = count(array_filter($keywords, fn (string $word): bool => str_contains($haystack, $word)));
            $keywordScore = (int) round($hits / count($keywords) * 100);
        }

        $categoryScore = $lost->category === $found->category ? 100 : 20;

        return (int) round($keywordScore * 0.65 + $categoryScore * 0.35);
    }

    /**
     * @return array<int, string>
     */
    private function keywords(string $text): array
    {
        $normalized = $this->normalize($text);
        $words = preg_split('/[^a-z0-9]+/', $normalized) ?: [];

        $stopWords = [
            'un', 'une', 'des', 'de', 'du', 'la', 'le', 'les', 'et', 'ou', 'a', 'au', 'aux',
            'en', 'sur', 'pour', 'par', 'avec', 'mon', 'ma', 'mes', 'ce', 'cet', 'cette', 'est',
            'qui', 'que', 'dans', 'je', 'il', 'elle', 'very', 'the', 'and', 'lost', 'found',
        ];

        $words = array_filter($words, fn (string $word): bool => mb_strlen($word) > 2 && ! in_array($word, $stopWords, true));

        return array_values(array_unique($words));
    }

    /** Normalisation francaise : minuscules, sans accents, ponctuation retiree. */
    private function normalize(string $text): string
    {
        $text = mb_strtolower(Str::ascii(trim($text)));

        return preg_replace('/[^a-z0-9]+/', ' ', $text) ?? $text;
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
