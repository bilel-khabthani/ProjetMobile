<?php

namespace App\Services\Moderation;

use Illuminate\Support\Facades\Cache;

/**
 * Point d'entree unique de la moderation : selectionne le driver configure
 * et met en cache les verdicts par empreinte de texte.
 */
class ModerationManager implements ModerationService
{
    private ?ModerationService $service = null;

    public function __construct(private readonly TextNormalizer $normalizer) {}

    public function moderate(string $text): ModerationResult
    {
        $ttl = (int) config('moderation.cache_ttl', 3600);

        if ($ttl <= 0) {
            return $this->service()->moderate($text);
        }

        return Cache::remember(
            'moderation:'.$this->fingerprint($text),
            $ttl,
            fn (): ModerationResult => $this->service()->moderate($text),
        );
    }

    public function fingerprint(string $text): string
    {
        return $this->normalizer->hash($text);
    }

    private function service(): ModerationService
    {
        if ($this->service !== null) {
            return $this->service;
        }

        $lexicon = new LexiconModerationService($this->normalizer);
        $openAi = new OpenAiModerationService(
            config('moderation.openai'),
            config('moderation.thresholds'),
        );

        $this->service = match (config('moderation.driver', 'chain')) {
            'none' => new NullModerationService,
            'lexicon' => $lexicon,
            'openai' => $openAi,
            default => new ChainModerationService(
                [$lexicon, $openAi],
                (bool) config('moderation.fail_open', true),
            ),
        };

        return $this->service;
    }
}
