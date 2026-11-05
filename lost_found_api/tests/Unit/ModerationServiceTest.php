<?php

namespace Tests\Unit;

use App\Services\Moderation\LexiconModerationService;
use App\Services\Moderation\TextNormalizer;
use Tests\TestCase;

class ModerationServiceTest extends TestCase
{
    public function test_it_normalises_obfuscated_text(): void
    {
        $normalizer = new TextNormalizer;

        $this->assertSame('connard', $normalizer->normalize('C0NN4RD'));
        $this->assertSame('fils de pute', $normalizer->normalize('  Fils   de   pute !! '));

        $spaced = $normalizer->collapseSpacedLetters($normalizer->tokens('m.e.r.d.e'));
        $this->assertContains('merde', $spaced);
    }

    public function test_lexicon_blocks_profanity_and_allows_clean_text(): void
    {
        $moderation = new LexiconModerationService(new TextNormalizer);

        $blocked = $moderation->moderate('Tu es un connard');
        $this->assertTrue($blocked->isBlocked());
        $this->assertContains('insult', $blocked->categories);

        $allowed = $moderation->moderate('Bonjour, je pense avoir trouve votre sac.');
        $this->assertFalse($allowed->isBlocked());
    }

    public function test_lexicon_detects_spaced_letters(): void
    {
        $moderation = new LexiconModerationService(new TextNormalizer);

        $this->assertTrue($moderation->moderate('c o n n a r d')->isBlocked());
    }
}
