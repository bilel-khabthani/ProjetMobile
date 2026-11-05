<?php

namespace App\Services\Moderation;

/**
 * Detection locale par lexique. C'est la premiere barriere : elle fonctionne
 * hors ligne et bloque instantanement les insultes les plus evidentes.
 */
class LexiconModerationService implements ModerationService
{
    /**
     * @var array<int, array{term: string, squeezed: string, category: string, phrase: bool}>
     */
    private array $entries = [];

    public function __construct(
        private readonly TextNormalizer $normalizer,
        ?string $path = null,
    ) {
        $this->load($path);
    }

    public function moderate(string $text): ModerationResult
    {
        if ($this->entries === []) {
            return ModerationResult::allow('lexicon');
        }

        $normalized = $this->normalizer->normalize($text);
        $tokens = $this->normalizer->collapseSpacedLetters($this->normalizer->tokens($text));
        $tokenSet = array_flip($tokens);
        $squeezedSet = array_flip(explode(' ', $this->normalizer->squeeze($text)));
        $padded = ' '.$normalized.' ';

        $categories = [];

        foreach ($this->entries as $entry) {
            $matched = $entry['phrase']
                ? str_contains($padded, ' '.$entry['term'].' ')
                : isset($tokenSet[$entry['term']]) || isset($squeezedSet[$entry['squeezed']]);

            if ($matched) {
                $categories[$entry['category']] = true;
            }
        }

        if ($categories !== []) {
            return ModerationResult::block(
                'lexicon',
                array_keys($categories),
                ['lexicon' => 1.0],
            );
        }

        return ModerationResult::allow('lexicon');
    }

    private function load(?string $path): void
    {
        $path ??= config('moderation.lexicon_path');

        if (! is_string($path) || ! is_file($path)) {
            return;
        }

        $lines = file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) ?: [];

        foreach ($lines as $line) {
            $line = trim($line);

            if ($line === '' || str_starts_with($line, '#')) {
                continue;
            }

            $parts = explode('|', $line, 2);
            $term = $this->normalizer->normalize($parts[0]);
            $category = trim($parts[1] ?? 'profanity');

            if ($term === '' || $category === '') {
                continue;
            }

            $this->entries[] = [
                'term' => $term,
                'squeezed' => $this->normalizer->squeeze($term),
                'category' => $category,
                'phrase' => str_contains($term, ' '),
            ];
        }
    }
}
