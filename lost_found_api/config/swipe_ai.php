<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Module Tinder Cards - analyse IA des correspondances
    |--------------------------------------------------------------------------
    |
    | Le deck est toujours disponible : le service produit une pre-analyse
    | locale (regles deterministes sur les scores du moteur de matching). Si
    | une cle OpenAI est fournie, l'ecran "Analyse IA" demande en plus une
    | explication redigee et un message pret a envoyer au trouveur.
    |
    | Aucun appel reseau n'est fait au chargement du deck : l'IA generative
    | reste declenchee a la demande pour maitriser le cout et la latence.
    |
    */

    'enabled' => (bool) env('SWIPE_AI_ENABLED', true),

    'openai' => [
        'api_key' => env('OPENAI_API_KEY'),
        'base_url' => env('OPENAI_BASE_URL', 'https://api.openai.com/v1'),
        'model' => env('SWIPE_AI_MODEL', 'gpt-4o-mini'),
        'timeout' => (int) env('SWIPE_AI_TIMEOUT', 12),
    ],

    /* Duree de mise en cache d'une analyse par correspondance. */
    'cache_ttl' => (int) env('SWIPE_AI_CACHE_TTL', 3600),

    /* Nombre maximum de cartes renvoyees par le deck. */
    'max_candidates' => (int) env('SWIPE_MAX_CANDIDATES', 30),

];
