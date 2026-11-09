<?php

namespace App\Services\Moderation;

/**
 * Execute plusieurs fournisseurs dans l'ordre et s'arrete au premier blocage.
 */
class ChainModerationService implements ModerationService
{
    /**
     * @param  array<int, ModerationService>  $services
     */
    public function __construct(
        private readonly array $services,
        private readonly bool $failOpen = true,
    ) {}

    public function moderate(string $text): ModerationResult
    {
        $anyAvailable = false;

        foreach ($this->services as $service) {
            $result = $service->moderate($text);

            if ($result->isBlocked()) {
                return $result;
            }

            if ($result->available) {
                $anyAvailable = true;
            }
        }

        if (! $anyAvailable && ! $this->failOpen) {
            return ModerationResult::block('chain', ['moderation_unavailable']);
        }

        return ModerationResult::allow('chain');
    }
}
