<?php

namespace Tests\Feature;

use App\Models\Item;
use App\Models\ItemMatch;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class MatchVerificationTest extends TestCase
{
    use RefreshDatabase;

    public function test_owner_can_verify_with_a_free_text_answer(): void
    {
        $owner = $this->verifiedUser();
        $match = $this->match($owner, $this->verifiedUser(), 'bande rouge et cadenas doré');

        $this->actingAs($owner, 'sanctum')
            ->postJson("/api/matches/{$match->id}/answer", [
                'answer_text' => 'Il a une bande rouge et un cadenas doré.',
            ])
            ->assertOk()
            ->assertJsonPath('verification.decision', 'YES')
            ->assertJsonPath('status', ItemMatch::STATUS_VERIFIED);

        $match->refresh();

        $this->assertSame('YES', $match->decision['answer']);
        $this->assertSame(1, $match->verification_attempts);
        $this->assertNotEmpty($match->decision['verification']['matched']);
    }

    public function test_wrong_answer_keeps_the_match_pending(): void
    {
        $owner = $this->verifiedUser();
        $match = $this->match($owner, $this->verifiedUser(), 'bande rouge et cadenas doré');

        $this->actingAs($owner, 'sanctum')
            ->postJson("/api/matches/{$match->id}/answer", [
                'answer_text' => 'Il est blanc avec une bande verte.',
            ])
            ->assertOk()
            ->assertJsonPath('status', ItemMatch::STATUS_PENDING);

        $match->refresh();

        $this->assertNotSame('YES', $match->decision['answer']);
        $this->assertSame(ItemMatch::STATUS_PENDING, $match->status);
    }

    public function test_finder_cannot_answer_for_the_owner(): void
    {
        $owner = $this->verifiedUser();
        $finder = $this->verifiedUser();
        $match = $this->match($owner, $finder, 'bande rouge et cadenas doré');

        $this->actingAs($finder, 'sanctum')
            ->postJson("/api/matches/{$match->id}/answer", [
                'answer_text' => 'bande rouge et cadenas doré',
            ])
            ->assertForbidden();

        $match->refresh();

        $this->assertArrayNotHasKey('answer', $match->decision);
        $this->assertSame(0, $match->verification_attempts);
    }

    public function test_binary_answer_still_works_for_backward_compatibility(): void
    {
        $owner = $this->verifiedUser();
        $match = $this->match($owner, $this->verifiedUser(), null);

        $this->actingAs($owner, 'sanctum')
            ->postJson("/api/matches/{$match->id}/answer", ['answer' => 'YES'])
            ->assertOk()
            ->assertJsonPath('verification.decision', 'YES')
            ->assertJsonPath('status', ItemMatch::STATUS_VERIFIED);
    }

    public function test_verification_requires_an_answer(): void
    {
        $owner = $this->verifiedUser();
        $match = $this->match($owner, $this->verifiedUser(), 'bande rouge');

        $this->actingAs($owner, 'sanctum')
            ->postJson("/api/matches/{$match->id}/answer", [])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('answer_text');
    }

    private function verifiedUser(): User
    {
        return User::factory()->create([
            'phone' => fake()->unique()->phoneNumber(),
            'phone_verified' => true,
        ]);
    }

    private function match(User $owner, User $finder, ?string $secret): ItemMatch
    {
        $lost = Item::create([
            'user_id' => $owner->id,
            'type' => Item::TYPE_LOST,
            'category' => 'sac',
            'title' => 'Sac Nike noir',
            'description' => 'Sac de sport noir avec une bande rouge.',
            'secret_detail' => $secret,
            'place_label' => 'Vestiaire A',
            'latitude' => 36.8065,
            'longitude' => 10.1815,
            'occurred_at' => now(),
            'status' => 'ACTIVE',
        ]);

        $found = Item::create([
            'user_id' => $finder->id,
            'type' => Item::TYPE_FOUND,
            'category' => 'sac',
            'title' => 'Sac noir à bande rouge',
            'description' => 'Sac noir trouvé avec une bande rouge et un cadenas doré.',
            'place_label' => 'Cafétéria',
            'latitude' => 36.8070,
            'longitude' => 10.1820,
            'occurred_at' => now(),
            'status' => 'ACTIVE',
        ]);

        return ItemMatch::create([
            'lost_item_id' => $lost->id,
            'found_item_id' => $found->id,
            'image_score' => 50,
            'location_score' => 100,
            'time_score' => 100,
            'text_score' => 90,
            'global_score' => 95,
            'status' => ItemMatch::STATUS_PENDING,
            'decision' => ['engine' => 'YES'],
            'verification_attempts' => 0,
        ]);
    }
}
