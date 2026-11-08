<?php

namespace App\Services\Moderation;

use App\Models\ModerationEvent;

/**
 * Resultat normalise d'une analyse de contenu.
 */
final class ModerationResult
{
    /**
     * @param  array<int, string>  $categories
     * @param  array<string, float>  $scores
     */
    public function __construct(
        public readonly bool $allowed,
        public readonly string $decision,
        public readonly array $categories = [],
        public readonly array $scores = [],
        public readonly string $provider = 'none',
        public readonly bool $available = true,
    ) {}

    /**
     * @param  array<int, string>  $categories
     * @param  array<string, float>  $scores
     */
    public static function allow(string $provider = 'none', array $scores = []): self
    {
        return new self(true, ModerationEvent::DECISION_ALLOW, [], $scores, $provider);
    }

    /**
     * @param  array<int, string>  $categories
     * @param  array<string, float>  $scores
     */
    public static function block(string $provider, array $categories, array $scores = []): self
    {
        return new self(false, ModerationEvent::DECISION_BLOCK, array_values(array_unique($categories)), $scores, $provider);
    }

    /**
     * Fournisseur indisponible : la decision revient a la politique fail-open.
     */
    public static function unavailable(string $provider): self
    {
        return new self(true, ModerationEvent::DECISION_ALLOW, [], [], $provider, false);
    }

    public function isBlocked(): bool
    {
        return ! $this->allowed;
    }
}
