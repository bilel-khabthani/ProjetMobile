<?php

namespace App\Services\Ai;

use App\Models\Item;
use App\Models\ItemMatch;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Module Tinder Cards - analyse IA d'une correspondance.
 *
 * Deux niveaux :
 *  - preview() : pre-analyse locale immediate, utilisee pour remplir le deck
 *    sans appel reseau (aucun cout, aucune latence) ;
 *  - analyze() : analyse generative OpenAI si une cle est configuree, avec
 *    repli automatique sur la pre-analyse locale en cas d'erreur.
 *
 * Le service ne recoit jamais le "secret_detail" : ce champ reste reserve a
 * la verification formelle du proprietaire (CDC 6.4.4).
 */
class SwipeAiService
{
    /** @var array<string, mixed> */
    private array $config;

    private const CATEGORY_LABELS = [
        'sac' => 'sac',
        'telephone' => 'téléphone',
        'cles' => 'clés',
        'papiers' => 'papiers',
        'vetement' => 'vêtement',
        'lunettes' => 'lunettes',
        'portefeuille' => 'portefeuille',
        'autre' => 'autre',
    ];

    public function __construct(
        private readonly TextAgreementService $agreement,
    ) {
        $this->config = (array) config('swipe_ai', []);
    }

    public function enabled(): bool
    {
        return (bool) ($this->config['enabled'] ?? false)
            && is_string($this->apiKey())
            && $this->apiKey() !== '';
    }

    /** Pre-analyse instantanee, sans appel externe. */
    public function preview(ItemMatch $match): array
    {
        return $this->heuristic($this->context($match));
    }

    /** Analyse detaillee : OpenAI si disponible, heuristique sinon. */
    public function analyze(ItemMatch $match): array
    {
        $context = $this->context($match);

        if (! $this->enabled()) {
            return $this->heuristic($context);
        }

        try {
            $response = Http::withToken((string) $this->apiKey())
                ->acceptJson()
                ->timeout(max(1, (int) ($this->config['openai']['timeout'] ?? 12)))
                ->post(
                    rtrim((string) ($this->config['openai']['base_url'] ?? 'https://api.openai.com/v1'), '/').'/chat/completions',
                    [
                        'model' => $this->config['openai']['model'] ?? 'gpt-4o-mini',
                        'temperature' => 0.2,
                        'max_tokens' => 500,
                        'response_format' => ['type' => 'json_object'],
                        'messages' => [
                            [
                                'role' => 'system',
                                'content' => $this->systemPrompt(),
                            ],
                            [
                                'role' => 'user',
                                'content' => json_encode(
                                    $context,
                                    JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES
                                ),
                            ],
                        ],
                    ]
                );

            if (! $response->successful()) {
                Log::warning('Swipe AI request failed.', [
                    'status' => $response->status(),
                ]);

                return $this->heuristic($context);
            }

            $content = $response->json('choices.0.message.content');
            $payload = is_string($content) ? json_decode($content, true) : null;

            if (! is_array($payload)) {
                return $this->heuristic($context);
            }

            return $this->normalize($payload, $context);
        } catch (\Throwable $exception) {
            // Aucune description d'objet n'est journalisee.
            Log::warning('Swipe AI unavailable.', [
                'exception' => $exception::class,
            ]);

            return $this->heuristic($context);
        }
    }

    /** Distance orthodromique entre les deux annonces, si geolocalisees. */
    public function distanceKm(ItemMatch $match): ?float
    {
        $lost = $match->lostItem;
        $found = $match->foundItem;

        if (! $lost || ! $found) {
            return null;
        }

        if ($lost->latitude === null || $found->latitude === null) {
            return null;
        }

        $earthRadius = 6371;
        $deltaLat = deg2rad((float) $found->latitude - (float) $lost->latitude);
        $deltaLon = deg2rad((float) $found->longitude - (float) $lost->longitude);

        $a = sin($deltaLat / 2) ** 2
            + cos(deg2rad((float) $lost->latitude))
            * cos(deg2rad((float) $found->latitude))
            * sin($deltaLon / 2) ** 2;

        return round($earthRadius * 2 * atan2(sqrt($a), sqrt(1 - $a)), 2);
    }

    /** Contexte minimal envoye au modele : aucune donnee secrete. */
    private function context(ItemMatch $match): array
    {
        $match->loadMissing(['lostItem.user', 'foundItem.user']);

        $lost = $match->lostItem;
        $found = $match->foundItem;

        $agreement = $lost && $found
            ? $this->agreement->analyze(
                $lost->title.' '.$lost->description,
                $found->title.' '.$found->description.' '.$found->place_label,
            )
            : ['score' => 0, 'shared' => [], 'contradictions' => []];

        return [
            'score_global' => (int) $match->global_score,
            'dimensions' => [
                'localisation' => (int) $match->location_score,
                'temps' => (int) $match->time_score,
                'texte' => (int) $match->text_score,
            ],
            'accord_texte' => $agreement,
            'distance_km' => $this->distanceKm($match),
            'objet_perdu' => $this->itemContext($lost),
            'objet_trouve' => $this->itemContext($found),
            'trouveur' => [
                'prenom' => $found?->user?->name,
                'score_confiance' => $found?->user?->trust_score,
                'objets_rendus' => $found?->user?->recovered_count,
            ],
        ];
    }

    private function itemContext(?Item $item): ?array
    {
        if (! $item) {
            return null;
        }

        $code = (string) $item->category;

        return [
            'titre' => $item->title,
            'description' => $item->description,
            'categorie' => self::CATEGORY_LABELS[$code] ?? $code,
            'lieu' => $item->place_label,
            'date' => $item->occurred_at?->toIso8601String(),
        ];
    }

    private function systemPrompt(): string
    {
        return <<<'PROMPT'
Tu es l'assistant IA de Lost&Found AI, une application de récupération d'objets perdus sur un campus.
Tu reçois deux annonces (objet perdu et objet trouvé) et les scores d'un moteur de matching.

Tu dois répondre UNIQUEMENT avec un objet JSON valide, sans texte autour, avec ce format :
{
  "verdict": "STRONG" | "POSSIBLE" | "WEAK",
  "confidence": 0-100,
  "summary": "une phrase de synthèse en français",
  "reasons": ["3 à 4 indices courts en français"],
  "tags": ["2 à 4 étiquettes courtes"],
  "icebreaker": "un message court, poli et prudent à envoyer au trouveur"
}

Règles :
- Ne jamais affirmer que l'objet appartient à quelqu'un : ce n'est qu'une piste.
- Si les indices sont faibles ou contradictoires, choisis WEAK et baisse la confiance.
- Le message doit demander une confirmation d'un détail distinctif, sans révéler d'information secrète.
- Reste en français, ton chaleureux et concis.
PROMPT;
    }

    /**
     * Valide et borne la reponse du modele : une reponse mal formee ne doit
     * jamais casser le deck ni afficher de contenu inattendu.
     */
    private function normalize(array $data, array $context): array
    {
        $verdict = strtoupper((string) ($data['verdict'] ?? ''));
        if (! in_array($verdict, ['STRONG', 'POSSIBLE', 'WEAK'], true)) {
            $verdict = $this->verdictForScore((int) ($context['score_global'] ?? 0));
        }

        $reasons = $this->stringList($data['reasons'] ?? [], 4);
        $tags = $this->stringList($data['tags'] ?? [], 4);

        $summary = trim((string) ($data['summary'] ?? ''));
        $icebreaker = trim((string) ($data['icebreaker'] ?? ''));

        return [
            'verdict' => $verdict,
            'confidence' => max(
                0,
                min(100, (int) ($data['confidence'] ?? $context['score_global'] ?? 0))
            ),
            'summary' => $summary !== ''
                ? $summary
                : $this->heuristic($context)['summary'],
            'reasons' => $reasons !== []
                ? $reasons
                : $this->heuristic($context)['reasons'],
            'tags' => $tags !== []
                ? $tags
                : $this->heuristic($context)['tags'],
            'icebreaker' => $icebreaker !== ''
                ? $icebreaker
                : $this->heuristic($context)['icebreaker'],
            'agreement' => $this->agreementPayload($context),
            'source' => 'openai',
        ];
    }

    /** Reponse deterministe utilisee en pre-analyse et en repli. */
    private function heuristic(array $context): array
    {
        $score = (int) ($context['score_global'] ?? 0);
        $dimensions = $context['dimensions'] ?? [];
        $lost = $context['objet_perdu'] ?? [];
        $found = $context['objet_trouve'] ?? [];

        $agreement = $this->agreementPayload($context);
        $shared = $agreement['shared'];
        $contradictions = $agreement['contradictions'];

        // Une contradiction explicite doit faire baisser la confiance : le
        // texte est un indice, pas une preuve.
        $score = max(0, min(100, $score - min(30, count($contradictions) * 12)));
        $verdict = $this->verdictForScore($score);

        $reasons = [];

        if ($shared !== []) {
            $reasons[] = 'Détails partagés : '.implode(', ', array_slice($shared, 0, 4)).'.';
        } elseif (($dimensions['texte'] ?? 0) >= 70) {
            $reasons[] = 'Les descriptions se recoupent sur plusieurs mots-clés.';
        }

        if (($dimensions['localisation'] ?? 0) >= 80) {
            $reasons[] = $this->distanceReason($context['distance_km'] ?? null);
        }

        if (($dimensions['temps'] ?? 0) >= 70) {
            $reasons[] = 'L’écart horaire est compatible avec la perte.';
        }

        if (($lost['categorie'] ?? null) !== null
            && ($lost['categorie'] ?? null) === ($found['categorie'] ?? null)) {
            $reasons[] = 'Les deux annonces concernent la même catégorie d’objet.';
        }

        if ($reasons === []) {
            $reasons[] = 'Les indices sont limités : une vérification auprès du trouveur est indispensable.';
        }

        $tags = array_values(array_filter([
            $found['categorie'] ?? null,
            ($dimensions['localisation'] ?? 0) >= 80 ? 'Très proche' : null,
            ($dimensions['temps'] ?? 0) >= 70 ? 'Même créneau' : null,
            $verdict === 'WEAK' ? 'À vérifier' : null,
        ]));

        $summary = match ($verdict) {
            'STRONG' => 'Le texte, le lieu et l’horaire convergent : cette piste mérite une vérification rapide.',
            'POSSIBLE' => 'Plusieurs indices concordent, mais un détail distinctif doit être confirmé avec le trouveur.',
            default => 'Quelques similitudes existent, mais les preuves restent insuffisantes pour conclure.',
        };

        $foundTitle = $found['titre'] ?? 'cet objet';
        $icebreaker = "Bonjour, votre annonce « {$foundTitle} » ressemble à l’objet que j’ai perdu. "
            .'Pourriez-vous me confirmer un détail distinctif avant que nous convenions d’un rendez-vous ?';

        return [
            'verdict' => $verdict,
            'confidence' => max(0, min(100, $score)),
            'summary' => $summary,
            'reasons' => array_slice($reasons, 0, 4),
            'tags' => array_slice($tags, 0, 4),
            'icebreaker' => $icebreaker,
            'agreement' => $agreement,
            'source' => 'heuristic',
        ];
    }

    /**
     * Forme stable de l'accord textuel transmise au client Flutter.
     *
     * @return array{score: int, shared: array<int, string>, contradictions: array<int, string>}
     */
    private function agreementPayload(array $context): array
    {
        $agreement = $context['accord_texte'] ?? [];

        return [
            'score' => max(0, min(100, (int) ($agreement['score'] ?? 0))),
            'shared' => $this->stringList($agreement['shared'] ?? [], 6),
            'contradictions' => $this->stringList($agreement['contradictions'] ?? [], 4),
        ];
    }

    private function verdictForScore(int $score): string
    {
        return match (true) {
            $score >= 80 => 'STRONG',
            $score >= 65 => 'POSSIBLE',
            default => 'WEAK',
        };
    }

    private function distanceReason(?float $distanceKm): string
    {
        if ($distanceKm === null) {
            return 'Les deux annonces concernent le même secteur.';
        }

        if ($distanceKm < 1) {
            return 'Les deux annonces sont à moins d’un kilomètre l’une de l’autre.';
        }

        return 'Les deux annonces sont distantes d’environ '.round($distanceKm).' km.';
    }

    /**
     * @return array<int, string>
     */
    private function stringList(mixed $value, int $limit): array
    {
        if (! is_array($value)) {
            return [];
        }

        $items = [];
        foreach ($value as $item) {
            if (! is_scalar($item)) {
                continue;
            }
            $text = trim((string) $item);
            if ($text !== '') {
                $items[] = $text;
            }
            if (count($items) >= $limit) {
                break;
            }
        }

        return $items;
    }

    private function apiKey(): ?string
    {
        $key = $this->config['openai']['api_key'] ?? null;

        return is_string($key) ? $key : null;
    }
}
