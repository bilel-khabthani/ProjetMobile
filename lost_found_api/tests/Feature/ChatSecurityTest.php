<?php

namespace Tests\Feature;

use App\Models\Item;
use App\Models\ItemMatch;
use App\Models\Message;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ChatSecurityTest extends TestCase
{
    use RefreshDatabase;

    public function test_verified_participants_can_exchange_and_read_messages(): void
    {
        $owner = $this->verifiedUser();
        $finder = $this->verifiedUser();
        $match = $this->match($owner, $finder, ItemMatch::STATUS_VERIFIED);

        $this->actingAs($owner, 'sanctum')
            ->postJson("/api/matches/{$match->id}/messages", [
                'body' => 'Bonjour, je pense que c\'est mon sac.',
            ])
            ->assertCreated()
            ->assertJsonPath('body', 'Bonjour, je pense que c\'est mon sac.')
            ->assertJsonPath('sender_id', $owner->id);

        $message = Message::sole();

        $this->actingAs($finder, 'sanctum')
            ->getJson("/api/matches/{$match->id}/messages")
            ->assertOk()
            ->assertJsonCount(1)
            ->assertJsonPath('0.id', $message->id)
            ->assertJsonPath('0.sender.name', $owner->name);

        $this->actingAs($finder, 'sanctum')
            ->postJson("/api/matches/{$match->id}/messages/read")
            ->assertOk()
            ->assertJsonPath('updated', 1);

        $this->assertNotNull($message->fresh()->read_at);
    }

    public function test_chat_is_locked_until_the_match_is_verified(): void
    {
        $owner = $this->verifiedUser();
        $match = $this->match($owner, $this->verifiedUser(), ItemMatch::STATUS_PENDING);

        $this->actingAs($owner, 'sanctum')
            ->getJson("/api/matches/{$match->id}/messages")
            ->assertForbidden();

        $this->actingAs($owner, 'sanctum')
            ->postJson("/api/matches/{$match->id}/messages", ['body' => 'Coucou'])
            ->assertForbidden();
    }

    public function test_outsider_cannot_read_or_write_in_a_match_chat(): void
    {
        $owner = $this->verifiedUser();
        $match = $this->match($owner, $this->verifiedUser(), ItemMatch::STATUS_VERIFIED);
        $outsider = $this->verifiedUser();

        $this->actingAs($outsider, 'sanctum')
            ->getJson("/api/matches/{$match->id}/messages")
            ->assertForbidden();

        $this->actingAs($outsider, 'sanctum')
            ->postJson("/api/matches/{$match->id}/messages", ['body' => 'Intrusion'])
            ->assertForbidden();

        $this->assertDatabaseCount('messages', 0);
    }

    public function test_recipient_can_report_a_message_but_not_their_own(): void
    {
        $owner = $this->verifiedUser();
        $finder = $this->verifiedUser();
        $match = $this->match($owner, $finder, ItemMatch::STATUS_VERIFIED);

        $message = Message::create([
            'match_id' => $match->id,
            'sender_id' => $owner->id,
            'body' => 'Message suspect',
        ]);

        $this->actingAs($owner, 'sanctum')
            ->postJson("/api/matches/{$match->id}/messages/{$message->id}/report", [
                'reason' => 'Contenu abusif',
            ])
            ->assertUnprocessable();

        $this->actingAs($finder, 'sanctum')
            ->postJson("/api/matches/{$match->id}/messages/{$message->id}/report", [
                'reason' => 'Contenu abusif',
            ])
            ->assertOk()
            ->assertJsonPath('report_reason', 'Contenu abusif');

        $this->assertNotNull($message->fresh()->reported_at);
    }

    public function test_low_trust_participant_cannot_open_chat(): void
    {
        $owner = $this->verifiedUser(trustScore: 20);
        $match = $this->match($owner, $this->verifiedUser(), ItemMatch::STATUS_VERIFIED);

        $this->actingAs($owner, 'sanctum')
            ->getJson("/api/matches/{$match->id}/messages")
            ->assertForbidden();
    }

    private function verifiedUser(int $trustScore = 50): User
    {
        return User::factory()->create([
            'phone' => fake()->unique()->phoneNumber(),
            'phone_verified' => true,
            'trust_score' => $trustScore,
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

    private function match(User $owner, User $finder, string $status): ItemMatch
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
            'status' => $status,
            'decision' => ['engine' => 'YES'],
            'verification_attempts' => 0,
            'verified_at' => $status === ItemMatch::STATUS_VERIFIED ? now() : null,
        ]);
    }
}
