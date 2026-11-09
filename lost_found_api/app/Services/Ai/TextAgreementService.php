<?php

namespace App\Services\Ai;

/**
 * Moteur local d'accord textuel en francais.
 *
 * Il compare deux textes courts (annonce perdue / annonce trouvee, ou reponse
 * du proprietaire / detail secret) sans appel reseau ni modele embarque. Le
 * calcul combine trois signaux complementaires :
 *
 *  - le coefficient de Dice sur les mots significatifs (recouvrement global) ;
 *  - la couverture du texte le plus court (un detail rare suffit parfois) ;
 *  - la similarite de bigrammes de caracteres (fautes de frappe, accords).
 *
 * S'y ajoutent un bonus de corroboration et une penalite lorsque deux textes
 * decrivent des caracteristiques incompatibles (couleurs, tailles, positions).
 * Le resultat est deterministe, explicable et utilisable comme repli lorsque
 * aucun modele generatif n'est configure.
 */
class TextAgreementService
{
    /** Mots grammaticaux et paraphrases qui ne portent aucun indice distinctif. */
    private const STOP_WORDS = [
        'a', 'au', 'aux', 'avec', 'ce', 'cet', 'cette', 'ces', 'dans', 'de', 'des',
        'du', 'elle', 'en', 'est', 'et', 'eux', 'il', 'ils', 'je', 'la', 'le', 'les',
        'leur', 'leurs', 'lui', 'ma', 'mais', 'me', 'mes', 'moi', 'mon', 'ne', 'nos',
        'notre', 'nous', 'on', 'ou', 'par', 'pas', 'pour', 'qu', 'que', 'qui', 'sa',
        'se', 'ses', 'son', 'sur', 'sous', 'ta', 'te', 'tes', 'toi', 'ton', 'tu',
        'un', 'une', 'vos', 'votre', 'vous', 'y', 'd', 'l', 's', 't', 'n', 'j', 'm',
        'c', 'ete', 'etre', 'trouve', 'trouvee', 'trouves', 'trouvees', 'perdu',
        'perdue', 'perdus', 'perdues', 'annonce', 'annonces', 'objet', 'objets',
        'pres', 'vers', 'environ', 'semble', 'semblent', 'ressemble', 'ressemblent',
        'contient', 'contenait', 'sans', 'plus', 'moins', 'tres', 'bien', 'peu',
        'tout', 'tous', 'toute', 'toutes', 'aussi', 'comme', 'autre', 'autres',
        'celui', 'celle', 'ceux', 'celles', 'dont', 'alors', 'donc', 'apres',
        'depuis', 'pendant', 'entre', 'chez', 'vers', 'ici', 'la-bas', 'voici',
        'voila', 'etait', 'etaient', 'avoir', 'ai', 'as', 'ont', 'suis', 'es',
        'sommes', 'etes', 'sont', 'peut', 'peuvent', 'pouvoir', 'fait', 'faire',
    ];

    /** Paires de caracteristiques incompatibles (formes normalisees). */
    private const OPPOSITES = [
        'noir' => ['blanc', 'blanche', 'claire'],
        'blanc' => ['noir', 'noire', 'fonce'],
        'rouge' => ['bleu', 'bleue', 'vert', 'verte'],
        'bleu' => ['rouge', 'vert', 'verte'],
        'vert' => ['rouge', 'bleu', 'bleue'],
        'dore' => ['argente'],
        'argente' => ['dore'],
        'grand' => ['petit', 'petite'],
        'petit' => ['grand', 'grande'],
        'gauche' => ['droite'],
        'droite' => ['gauche'],
        'devant' => ['derriere'],
        'derriere' => ['devant'],
        'interieur' => ['exterieur'],
        'exterieur' => ['interieur'],
        'ouvert' => ['ferme', 'fermee'],
        'ferme' => ['ouvert', 'ouverte'],
        'neuf' => ['casse', 'raye', 'abime'],
        'casse' => ['neuf'],
        'cuir' => ['tissu', 'plastique'],
        'tissu' => ['cuir', 'plastique'],
        'plastique' => ['cuir', 'tissu', 'metal'],
        'metal' => ['plastique'],
        'matin' => ['soir', 'soiree'],
        'soir' => ['matin'],
        'avant' => ['apres'],
        'apres' => ['avant'],
    ];

    /** Termes les plus discriminants : affiches en premier dans l'interface. */
    private const DISTINCTIVE = [
        'noir', 'blanc', 'rouge', 'bleu', 'vert', 'jaune', 'gris', 'marron',
        'beige', 'rose', 'violet', 'orange', 'dore', 'argente', 'transparent',
        'cuir', 'tissu', 'plastique', 'metal', 'bois', 'verre', 'nylon', 'coton',
        'sac', 'telephone', 'cle', 'portefeuille', 'lunette', 'vetement', 'papier',
        'montre', 'chargeur', 'ecouteur', 'gourde', 'bouteille', 'parapluie',
        'casque', 'carte', 'portefeuille', 'trousseau',
        'bande', 'rayure', 'raye', 'logo', 'poche', 'zip', 'fermeture', 'cadenas',
        'dragonne', 'autocollant', 'etui', 'coque', 'fissure', 'badge', 'brode',
        'inscription', 'initiales', 'etiquette', 'porte-cle', 'serviette',
        'grand', 'petit', 'moyen', 'large', 'fin', 'epais', 'gauche', 'droite',
    ];

    /** Caracteres accentues -> equivalent ASCII. */
    private const ACCENTS = [
        'à' => 'a', 'â' => 'a', 'ä' => 'a', 'á' => 'a', 'ã' => 'a', 'å' => 'a',
        'ç' => 'c',
        'è' => 'e', 'é' => 'e', 'ê' => 'e', 'ë' => 'e',
        'ì' => 'i', 'í' => 'i', 'î' => 'i', 'ï' => 'i',
        'ò' => 'o', 'ó' => 'o', 'ô' => 'o', 'õ' => 'o', 'ö' => 'o',
        'ù' => 'u', 'ú' => 'u', 'û' => 'u', 'ü' => 'u',
        'ÿ' => 'y', 'ñ' => 'n',
        'œ' => 'oe', 'æ' => 'ae',
    ];

    /** Mots qui se terminent par « s » ou « x » sans etre des pluriels. */
    private const INVARIABLES = [
        'gris', 'bois', 'mois', 'pays', 'tapis', 'cours', 'temps', 'corps', 'bras',
        'pas', 'repas', 'cas', 'bas', 'os', 'dos', 'trois', 'voix', 'noix', 'prix',
        'deux', 'cheveux', 'yeux', 'cieux', 'voeux', 'fils', 'sens', 'divers',
    ];

    /**
     * Compare deux descriptions et renvoie un accord exploitable par l'UI.
     *
     * @return array{score: int, shared: array<int, string>, contradictions: array<int, string>, terms: array{left: int, right: int}}
     */
    public function analyze(string $left, string $right): array
    {
        $leftNormalized = $this->normalize($left);
        $rightNormalized = $this->normalize($right);

        $leftTokens = $this->tokens($leftNormalized);
        $rightTokens = $this->tokens($rightNormalized);

        $empty = [
            'score' => 0,
            'shared' => [],
            'contradictions' => [],
            'terms' => ['left' => count($leftTokens), 'right' => count($rightTokens)],
        ];

        if ($leftTokens === [] || $rightTokens === []) {
            return $empty;
        }

        $shared = $this->sortDistinctive(
            array_values(array_intersect($leftTokens, $rightTokens))
        );
        $contradictions = $this->contradictions($leftTokens, $rightTokens);

        $dice = $this->dice($leftTokens, $rightTokens);
        $coverage = $this->coverage($leftTokens, $rightTokens);
        $bigram = $this->bigramSimilarity($leftNormalized, $rightNormalized);

        // 45 % recouvrement global, 35 % couverture, 20 % tolerance aux fautes.
        $score = (0.45 * $dice + 0.35 * $coverage + 0.20 * $bigram) * 100;

        // Bonus de corroboration : plusieurs details partages renforcent la piste.
        $score += min(12, count($shared) * 2);

        // Une description entierement contenue dans l'autre est un signal fort.
        if ($this->contains($leftNormalized, $rightNormalized)) {
            $score = max($score, 88);
        }

        // Une contradiction explicite doit peser plus qu'un mot commun.
        $score -= min(30, count($contradictions) * 12);

        return [
            'score' => $this->clamp($score),
            'shared' => array_slice($shared, 0, 6),
            'contradictions' => array_slice($contradictions, 0, 4),
            'terms' => ['left' => count($leftTokens), 'right' => count($rightTokens)],
        ];
    }

    /**
     * Evalue la reponse libre du proprietaire contre le detail secret.
     *
     * @return array{score: int, decision: string, matched: array<int, string>, contradictions: array<int, string>, neutral: bool}
     */
    public function scoreAnswer(string $answer, ?string $secretDetail): array
    {
        $secret = trim((string) $secretDetail);
        $answer = trim($answer);

        if ($secret === '') {
            // Aucun secret enregistre : on ne bloque pas un proprietaire legitime.
            return [
                'score' => 50,
                'decision' => 'UNSURE',
                'matched' => [],
                'contradictions' => [],
                'neutral' => true,
            ];
        }

        if ($answer === '') {
            return [
                'score' => 0,
                'decision' => 'NO',
                'matched' => [],
                'contradictions' => [],
                'neutral' => false,
            ];
        }

        $analysis = $this->analyze($secret, $answer);

        return [
            'score' => $analysis['score'],
            'decision' => match (true) {
                $analysis['score'] >= 65 => 'YES',
                $analysis['score'] >= 32 => 'UNSURE',
                default => 'NO',
            },
            'matched' => $analysis['shared'],
            'contradictions' => $analysis['contradictions'],
            'neutral' => false,
        ];
    }

    /** Normalise un texte francais : minuscules, sans accents ni ponctuation. */
    public function normalize(string $text): string
    {
        $text = mb_strtolower(trim($text));
        $text = strtr($text, self::ACCENTS);
        $text = preg_replace('/[^a-z0-9]+/u', ' ', $text) ?? $text;

        return trim(preg_replace('/\s+/', ' ', $text) ?? $text);
    }

    /**
     * Mots significatifs du texte, sans doublons.
     *
     * @return array<int, string>
     */
    private function tokens(string $normalized): array
    {
        $words = preg_split('/[^a-z0-9]+/', $normalized) ?: [];
        $tokens = [];

        foreach ($words as $word) {
            if ($word === '') {
                continue;
            }

            if (ctype_digit($word)) {
                // Les nombres (taille, modele, etage) sont de tres bons indices.
                if (mb_strlen($word) >= 2) {
                    $tokens[] = $word;
                }

                continue;
            }

            if (mb_strlen($word) < 3 || in_array($word, self::STOP_WORDS, true)) {
                continue;
            }

            $tokens[] = $this->singularize($word);
        }

        return array_values(array_unique($tokens));
    }

    private function singularize(string $word): string
    {
        if (in_array($word, self::INVARIABLES, true)) {
            return $word;
        }

        $length = mb_strlen($word);

        if ($length > 4 && str_ends_with($word, 's')) {
            return mb_substr($word, 0, -1);
        }

        if ($length > 4 && str_ends_with($word, 'x')) {
            return mb_substr($word, 0, -1);
        }

        return $word;
    }

    /**
     * @param  array<int, string>  $tokens
     * @return array<int, string>
     */
    private function sortDistinctive(array $tokens): array
    {
        $priority = array_flip(self::DISTINCTIVE);

        usort($tokens, function (string $left, string $right) use ($priority): int {
            $leftPriority = $priority[$left] ?? 1000;
            $rightPriority = $priority[$right] ?? 1000;

            return $leftPriority <=> $rightPriority ?: strcmp($left, $right);
        });

        return $tokens;
    }

    /**
     * @param  array<int, string>  $left
     * @param  array<int, string>  $right
     */
    private function dice(array $left, array $right): float
    {
        $intersection = count(array_intersect($left, $right));
        $total = count($left) + count($right);

        return $total === 0 ? 0.0 : (2 * $intersection) / $total;
    }

    /**
     * @param  array<int, string>  $left
     * @param  array<int, string>  $right
     */
    private function coverage(array $left, array $right): float
    {
        $shortest = min(count($left), count($right));

        if ($shortest === 0) {
            return 0.0;
        }

        return count(array_intersect($left, $right)) / $shortest;
    }

    /**
     * @param  array<int, string>  $left
     * @param  array<int, string>  $right
     * @return array<int, string>
     */
    private function contradictions(array $left, array $right): array
    {
        $result = [];

        foreach (self::OPPOSITES as $word => $opposites) {
            if (! in_array($word, $left, true)) {
                continue;
            }

            foreach ($opposites as $opposite) {
                if (! in_array($opposite, $right, true)) {
                    continue;
                }

                $pair = [$word, $opposite];
                sort($pair);
                $result[] = implode(' ↔ ', $pair);
            }
        }

        return array_values(array_unique($result));
    }

    private function bigramSimilarity(string $left, string $right): float
    {
        $left = preg_replace('/[^a-z0-9]/', '', $left) ?? '';
        $right = preg_replace('/[^a-z0-9]/', '', $right) ?? '';

        if ($left === '' || $right === '') {
            return 0.0;
        }

        $leftGrams = $this->bigrams($left);
        $rightGrams = $this->bigrams($right);
        $total = count($leftGrams) + count($rightGrams);

        if ($total === 0) {
            return 0.0;
        }

        return (2 * count(array_intersect($leftGrams, $rightGrams))) / $total;
    }

    /**
     * @return array<int, string>
     */
    private function bigrams(string $value): array
    {
        $length = mb_strlen($value);

        if ($length < 2) {
            return [$value];
        }

        $grams = [];
        for ($index = 0; $index < $length - 1; $index++) {
            $grams[] = mb_substr($value, $index, 2);
        }

        return $grams;
    }

    private function contains(string $left, string $right): bool
    {
        if ($left === '' || $right === '') {
            return false;
        }

        return str_contains($left, $right) || str_contains($right, $left);
    }

    private function clamp(float $value): int
    {
        return (int) round(max(0, min(100, $value)));
    }
}
