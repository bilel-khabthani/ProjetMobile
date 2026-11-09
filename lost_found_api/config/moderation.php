<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Moderation du chat
    |--------------------------------------------------------------------------
    |
    | La moderation combine un lexique local (francais, anglais, arabizi et
    | arabe) et, si une cle est fournie, l'endpoint gratuit de moderation
    | d'OpenAI. Le lexique reste actif en premier pour bloquer instantanement
    | les insultes evidentes, meme sans acces reseau.
    |
    | Drivers : "chain" (lexique + OpenAI), "lexicon", "openai", "none".
    |
    */

    'driver' => env('MODERATION_DRIVER', 'chain'),

    'openai' => [
        'api_key' => env('OPENAI_API_KEY'),
        'base_url' => env('OPENAI_BASE_URL', 'https://api.openai.com/v1'),
        'model' => env('OPENAI_MODERATION_MODEL', 'omni-moderation-latest'),
        'timeout' => (int) env('OPENAI_MODERATION_TIMEOUT', 5),
    ],

    /*
    | En cas d'indisponibilite du fournisseur externe : true laisse passer le
    | message (le lexique a deja filtre), false bloque par precaution.
    */
    'fail_open' => (bool) env('MODERATION_FAIL_OPEN', true),

    /*
    | Seuils par categorie OpenAI. Une categorie depasse son seuil si le score
    | renvoye est superieur ou egal a la valeur configuree.
    */
    'thresholds' => [
        'harassment' => 0.50,
        'harassment/threatening' => 0.40,
        'hate' => 0.40,
        'hate/threatening' => 0.30,
        'self-harm' => 0.50,
        'self-harm/intent' => 0.40,
        'self-harm/instructions' => 0.40,
        'sexual' => 0.60,
        'sexual/minors' => 0.20,
        'violence' => 0.70,
        'violence/graphic' => 0.50,
        'illicit' => 0.60,
        'illicit/violent' => 0.40,
    ],

    'lexicon_path' => resource_path('moderation/lexicon.txt'),

    'cache_ttl' => (int) env('MODERATION_CACHE_TTL', 3600),

    'max_length' => (int) env('MODERATION_MAX_LENGTH', 2000),

    /*
    | Sanction appliquee au score de confiance pour un message bloque.
    | 0 desactive la sanction automatique (arbitrage humain uniquement).
    */
    'strike_trust_points' => (int) env('MODERATION_STRIKE_POINTS', -5),

    /*
    | Nombre de messages bloques (24 h) a partir duquel la sanction de score
    | est appliquee. Les messages restent bloques dans tous les cas.
    */
    'strike_threshold' => (int) env('MODERATION_STRIKE_THRESHOLD', 1),

];
