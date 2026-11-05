<?php

namespace App\Services\Moderation;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Appel a l'endpoint de moderation d'OpenAI (gratuit).
 *
 * Le service est optionnel : sans cle API, il se declare indisponible et la
 * politique fail-open/fail-closed du ChainModerationService s'applique.
 */
class OpenAiModerationService implements ModerationService
{
    /**
     * @param  array{api_key: ?string, base_url: string, model: string, timeout: int}  $config
     * @param  array<string, float>  $thresholds
     */
    public function __construct(
        private readonly array $config,
        private readonly array $thresholds,
    ) {}

    public function moderate(string $text): ModerationResult
    {
        $apiKey = $this->config['api_key'] ?? null;

        if (! is_string($apiKey) || $apiKey === '') {
            return ModerationResult::unavailable('openai');
        }

        try {
            $response = Http::withToken($apiKey)
                ->acceptJson()
                ->timeout(max(1, (int) ($this->config['timeout'] ?? 5)))
                ->post(rtrim($this->config['base_url'], '/').'/moderations', [
                    'model' => $this->config['model'],
                    'input' => $text,
                ]);

            if (! $response->successful()) {
                Log::warning('OpenAI moderation request failed.', [
                    'status' => $response->status(),
                ]);

                return ModerationResult::unavailable('openai');
            }

            $result = $response->json('results.0', []);
            $scores = $result['category_scores'] ?? [];
            $flagged = [];

            foreach ($this->thresholds as $category => $threshold) {
                if (($scores[$category] ?? 0.0) >= $threshold) {
                    $flagged[] = $category;
                }
            }

            foreach (($result['categories'] ?? []) as $category => $isFlagged) {
                if ($isFlagged && ! in_array($category, $flagged, true)) {
                    $flagged[] = $category;
                }
            }

            if ($flagged !== []) {
                return ModerationResult::block('openai', $flagged, $scores);
            }

            return ModerationResult::allow('openai', $scores);
        } catch (\Throwable $exception) {
            // Aucun contenu du message n'est journalise.
            Log::warning('OpenAI moderation unavailable.', [
                'exception' => $exception::class,
            ]);

            return ModerationResult::unavailable('openai');
        }
    }
}
