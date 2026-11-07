<?php

namespace Tests\Feature;

use App\Models\Item;
use App\Models\ItemMatch;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SwipeControllerTest extends TestCase
{
    use RefreshDatabase;

    public function test_deck_returns_owner_candidates_with_an_ai_preview(): void
    {
        $owner = $this->verifiedUser();
        $finder = $this->verifiedUser();

        $lost = $this->item($owner, Item::TYPE_LOST);
        $found = $this->item($finder, Item::TYPE_FOUND);

        $response = $this->actingAs($owner, 'sanctum')->getJson('/api/swipe/deck');

        $response->assertOk()
            ->assertJsonPath('lost_items_count', 1)
            ->assertJsonPath('candidates.0.found_item.id', $found->id)
            ->assertJsonPath('candidates.0.ai.source', 'heuristic')
            ->assertJsonCount(1, 'candidates');

        $this->assertDatabaseHas('matches', [
            'lost_item_id' => $lost->id,
            'found_item_id' => $found->id,
        ]);
    }

    public function test_deck_requires_a_verified_phone(): void
    {
        $user = User::factory()->create([
            'phone' => fake()->unique()->phoneNumber(),
            'phone_verified' => false,
        ]);

        $this->actingAs($user, 'sanctum')
            ->getJson('/api/swipe/deck')
            ->assertForbidden()
            ->assertJsonPath('code', 'phone_unverified');
    }

    public function test_unauthenticated_request_returns_401(): void
    {
        $this->getJson('/api/swipe/deck')->assertUnauthorized();
    }

    public function test_like_decision_records_history_and_verifies_match(): void
    {
        $owner = $this->verifiedUser();
        $match = $this->match($owner, $this->verifiedUser());

        $response = $this->actingAs($owner, 'sanctum')->postJson(
            "/api/swipe/{$match->id}/decision",
            ['direction' => 'LIKE', 'ai_confidence' => 91]
        );

        $response->assertOk()
            ->assertJsonPath('direction', 'LIKE')
            ->assertJsonPath('answer', 'YES');

        $match->refresh();
        $this->assertSame('YES', $match->decision['answer']);
        $this->assertSame(ItemMatch::STATUS_VERIFIED, $match->status);
        $this->assertSame(1, $match->verification_attempts);

        $this->assertDatabaseHas('swipe_decisions', [
            'user_id' => $owner->id,
            'item_match_id' => $match->id,
            'direction' => 'LIKE',
            'ai_confidence' => 91,
        ]);
    }

    public function test_pass_decision_keeps_match_pending(): void
    {
        $owner = $this->verifiedUser();
        $match = $this->match($owner, $this->verifiedUser());

        $this->actingAs($owner, 'sanctum')
            ->postJson("/api/swipe/{$match->id}/decision", ['direction' => 'PASS'])
            ->assertOk()
            ->assertJsonPath('answer', 'NO');

        $match->refresh();
        $this->assertSame('NO', $match->decision['answer']);
        $this->assertSame(ItemMatch::STATUS_PENDING, $match->status);
        $this->assertDatabaseHas('swipe_decisions', [
            'user_id' => $owner->id,
            'item_match_id' => $match->id,
            'direction' => 'PASS',
        ]);
    }

    public function test_non_participant_cannot_decide_on_a_match(): void
    {
        $owner = $this->verifiedUser();
        $match = $this->match($owner, $this->verifiedUser());
        $outsider = $this->verifiedUser();

        $this->actingAs($outsider, 'sanctum')
            ->postJson("/api/swipe/{$match->id}/decision", ['direction' => 'LIKE'])
            ->assertForbidden();

        $this->assertDatabaseMissing('swipe_decisions', [
            'user_id' => $outsider->id,
            'item_match_id' => $match->id,
        ]);
    }

    public function test_finder_cannot_answer_a_swipe_card_as_the_owner(): void
    {
        $owner = $this->verifiedUser();
        $finder = $this->verifiedUser();
        $match = $this->match($owner, $finder);

        $this->actingAs($finder, 'sanctum')
            ->postJson("/api/swipe/{$match->id}/decision", ['direction' => 'LIKE'])
            ->assertForbidden();

        $match->refresh();
        $this->assertSame(ItemMatch::STATUS_PENDING, $match->status);
        $this->assertArrayNotHasKey('answer', $match->decision);
    }

    public function test_insight_falls_back_to_the_local_heuristic_without_a_key(): void
    {
        $owner = $this->verifiedUser();
        $match = $this->match($owner, $this->verifiedUser());

        $this->actingAs($owner, 'sanctum')
            ->getJson("/api/swipe/{$match->id}/insight")
            ->assertOk()
            ->assertJsonPath('insight.source', 'heuristic')
            ->assertJsonStructure([
                'insight' => [
                    'verdict',
                    'confidence',
                    'summary',
                    'reasons',
                    'tags',
                    'icebreaker',
                    'source',
                ],
            ])
            ->assertJsonMissingPath('insight.secret_detail');
    }

    private function verifiedUser(): User
    {
        return User::factory()->create([
            'phone' => fake()->unique()->phoneNumber(),
            'phone_verified' => true,
        ]);
    }

    private function item(User $user, string $type): Item
    {
        return Item::create([
            'user_id' => $user->id,
            'type' => $type,
            'category' => 'sac',
            'title' => 'Sac Nike noir',
            'description' => 'Sac de sport noir avec une bande rouge.',
            'place_label' => 'Vestiaire A',
            'latitude' => 36.8065,
            'longitude' => 10.1815,
            'occurred_at' => now(),
            'status' => 'ACTIVE',
        ]);
    }

    private function match(User $owner, User $finder): ItemMatch
    {
        $lost = $this->item($owner, Item::TYPE_LOST);
        $found = $this->item($finder, Item::TYPE_FOUND);

        return ItemMatch::create([
            'lost_item_id' => $lost->id,
            'found_item_id' => $found->id,
            'image_score' => 100,
            'location_score' => 100,
            'time_score' => 100,
            'text_score' => 100,
            'global_score' => 100,
            'status' => ItemMatch::STATUS_PENDING,
            'decision' => ['engine' => 'YES'],
            'verification_attempts' => 0,
        ]);
    }
}
