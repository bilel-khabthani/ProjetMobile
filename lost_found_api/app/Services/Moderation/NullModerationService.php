<?php

namespace App\Services\Moderation;

class NullModerationService implements ModerationService
{
    public function moderate(string $text): ModerationResult
    {
        return ModerationResult::allow('none');
    }
}
