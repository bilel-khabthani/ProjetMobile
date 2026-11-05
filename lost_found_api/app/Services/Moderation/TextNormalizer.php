<?php

namespace App\Services\Moderation;

use Illuminate\Support\Str;

/**
 * Normalise un texte avant comparaison au lexique.
 *
 * Objectif : neutraliser les contournements simples (casse, accents,
 * leetspeak, lettres répétées, espaces entre les lettres) sans modifier le
 * texte original stocké en base.
 */
class TextNormalizer
{
    /**
     * @return array<string, string>
     */
    private function leetMap(): array
    {
        return [
            '0' => 'o', '1' => 'i', '3' => 'e', '4' => 'a', '5' => 's',
            '7' => 't', '8' => 'b', '9' => 'g', '@' => 'a', '$' => 's',
            '€' => 'e', '£' => 'l',
        ];
    }

    public function normalize(string $text): string
    {
        $text = mb_strtolower(trim($text), 'UTF-8');
        $text = strtr($text, $this->leetMap());
        $text = Str::ascii($text);

        // Diacritiques arabes (harakat) et tatweel.
        $text = preg_replace('/[\x{064B}-\x{065F}\x{0670}\x{0640}]/u', '', $text) ?? $text;

        // Variantes de lettres arabes pour stabiliser la comparaison.
        $text = strtr($text, [
            'أ' => 'ا', 'إ' => 'ا', 'آ' => 'ا', 'ى' => 'ي', 'ة' => 'ه',
            'ؤ' => 'و', 'ئ' => 'ي',
        ]);

        // Ponctuation et symboles -> espaces.
        $text = preg_replace('/[^\p{L}\p{N}\s]+/u', ' ', $text) ?? $text;

        // Réduit les répétitions excessives : "connnnard" -> "connard".
        $text = preg_replace('/(.)\1{2,}/u', '$1$1', $text) ?? $text;

        return trim(preg_replace('/\s+/u', ' ', $text) ?? $text);
    }

    /**
     * Variante où toutes les lettres doublées sont réduites, pour rattraper
     * les étirements ("puuussy" -> "pusy").
     */
    public function squeeze(string $text): string
    {
        return preg_replace('/(.)\1+/u', '$1', $this->normalize($text)) ?? '';
    }

    /**
     * @return array<int, string>
     */
    public function tokens(string $text): array
    {
        $normalized = $this->normalize($text);

        return $normalized === '' ? [] : explode(' ', $normalized);
    }

    /**
     * Recollle les suites de lettres isolées : "f u c k" -> "fuck".
     *
     * @param  array<int, string>  $tokens
     * @return array<int, string>
     */
    public function collapseSpacedLetters(array $tokens): array
    {
        $result = [];
        $buffer = '';

        foreach ($tokens as $token) {
            if (mb_strlen($token) === 1 && ctype_alpha($token)) {
                $buffer .= $token;

                continue;
            }

            if ($buffer !== '') {
                $result[] = mb_strlen($buffer) >= 3 ? $buffer : implode(' ', mb_str_split($buffer));
                $buffer = '';
            }

            $result[] = $token;
        }

        if ($buffer !== '') {
            $result[] = mb_strlen($buffer) >= 3 ? $buffer : implode(' ', mb_str_split($buffer));
        }

        return $result;
    }

    public function hash(string $text): string
    {
        return hash('sha256', $this->normalize($text));
    }
}
