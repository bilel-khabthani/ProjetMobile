<?php

namespace App\Services\Moderation;

interface ModerationService
{
    public function moderate(string $text): ModerationResult;
}
