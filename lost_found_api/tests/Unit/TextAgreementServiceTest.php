<?php

namespace Tests\Unit;

use App\Services\Ai\TextAgreementService;
use PHPUnit\Framework\TestCase;

class TextAgreementServiceTest extends TestCase
{
    private TextAgreementService $agreement;

    protected function setUp(): void
    {
        parent::setUp();

        $this->agreement = new TextAgreementService;
    }

    public function test_it_scores_matching_descriptions_higher_than_unrelated_ones(): void
    {
        $close = $this->agreement->analyze(
            'Sac de sport noir avec une bande rouge et un cadenas doré.',
            'Sac noir trouvé avec une bande rouge et un cadenas doré.'
        );

        $far = $this->agreement->analyze(
            'Sac de sport noir avec une bande rouge et un cadenas doré.',
            'Trousseau de clés avec un porte-clés vert.'
        );

        $this->assertGreaterThan(70, $close['score']);
        $this->assertLessThan($close['score'], $far['score']);
        $this->assertContains('bande', $close['shared']);
        $this->assertContains('rouge', $close['shared']);
    }

    public function test_it_flags_contradicting_colors(): void
    {
        $result = $this->agreement->analyze(
            'Sac noir avec une bande rouge.',
            'Sac blanc avec une bande bleue.'
        );

        $this->assertNotEmpty($result['contradictions']);

        $contradictions = implode(' | ', $result['contradictions']);
        $this->assertStringContainsString('blanc', $contradictions);
        $this->assertStringContainsString('rouge', $contradictions);
    }

    public function test_it_accepts_an_answer_that_matches_the_secret_detail(): void
    {
        $result = $this->agreement->scoreAnswer(
            'Il a une bande rouge et un cadenas doré.',
            'bande rouge et cadenas doré'
        );

        $this->assertSame('YES', $result['decision']);
        $this->assertContains('bande', $result['matched']);
        $this->assertFalse($result['neutral']);
    }

    public function test_it_does_not_accept_a_contradicting_answer(): void
    {
        $result = $this->agreement->scoreAnswer(
            'Il est blanc avec une bande verte.',
            'bande rouge et cadenas doré'
        );

        $this->assertNotSame('YES', $result['decision']);
        $this->assertNotEmpty($result['contradictions']);
    }

    public function test_it_stays_neutral_without_a_secret_detail(): void
    {
        $result = $this->agreement->scoreAnswer('n importe quoi', null);

        $this->assertTrue($result['neutral']);
        $this->assertSame('UNSURE', $result['decision']);
    }
}
