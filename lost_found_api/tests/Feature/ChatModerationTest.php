<?php

namespace Tests\Feature;

use App\Events\MessageSent;
use App\Events\MessagesRead;
use App\Models\Item;
use App\Models\ItemMatch;
use App\Models\Message;
use App\Models\ModerationEvent;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ChatModerationTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        config([
            'moderation.driver' => 'lexicon',
            'moderation.strike_trust_points' => -5,
            'moderation.strike_threshold' => 1,
        ]);
    }

    public function test_non_participant_cannot_access_chat(): void
    {
        [$match] = $this->makeMatch();
        $intruder = User::factory()->create(['phone_verified' => true]);

        Sanctum::actingAs($intruder);

        $this->getJson("/api/matches/{$match->id}/messages")->assertForbidden();
        $this->postJson("/api/matches/{$match->id}/messages", ['body' => 'Bonjour'])
            ->assertForbidden();
    }

    public function test_chat_is_locked_while_match_is_pending(): void
    {
        [$match, $owner] = $this->makeMatch(ItemMatch::STATUS_PENDING);

        Sanctum::actingAs($owner);

        $this->postJson("/api/matches/{$match->id}/messages", ['body' => 'Bonjour'])
            ->assertForbidden();
    }

    public function test_participants_can_send_read_and_mark_messages(): void
    {
        [$match, $owner, $finder] = $this->makeMatch();
        Event::fake([MessageSent::class]);

        Sanctum::actingAs($owner);

        $sent = $this->postJson("/api/matches/{$match->id}/messages", [
            'body' => 'Bonjour, avez-vous encore le sac ?',
        ])->assertCreated()
            ->assertJsonPath('is_mine', true)
            ->assertJsonPath('status', Message::STATUS_APPROVED);

        $messageId = $sent->json('id');

        Sanctum::actingAs($finder);

        $this->getJson("/api/matches/{$match->id}/messages")
            ->assertOk()
            ->assertJsonCount(1)
            ->assertJsonPath('0.id', $messageId)
            ->assertJsonPath('0.is_mine', false);

        $this->postJson("/api/matches/{$match->id}/messages/read")
            ->assertOk()
            ->assertJsonPath('updated', 1);

        $this->assertNotNull(Message::find($messageId)->read_at);

        Event::assertDispatched(MessageSent::class);
    }

    public function test_inappropriate_message_is_blocked_audited_and_penalised(): void
    {
        [$match, $owner] = $this->makeMatch();

        Sanctum::actingAs($owner);

        $this->postJson("/api/matches/{$match->id}/messages", [
            'body' => 'Tu es un connard',
        ])->assertUnprocessable()
            ->assertJsonPath('code', 'message_blocked')
            ->assertJsonPath('strikes', 1);

        $this->assertDatabaseCount('messages', 0);
        $this->assertDatabaseHas('moderation_events', [
            'user_id' => $owner->id,
            'match_id' => $match->id,
            'decision' => ModerationEvent::DECISION_BLOCK,
        ]);
        $this->assertSame(45, $owner->fresh()->trust_score);
    }

    public function test_obfuscated_insult_is_still_blocked(): void
    {
        [$match, $owner] = $this->makeMatch();

        Sanctum::actingAs($owner);

        $this->postJson("/api/matches/{$match->id}/messages", [
            'body' => 'c0nn4rd',
        ])->assertUnprocessable()
            ->assertJsonPath('code', 'message_blocked');
    }

    public function test_participant_can_report_a_message(): void
    {
        [$match, $owner, $finder] = $this->makeMatch();

        Sanctum::actingAs($owner);
        $messageId = $this->postJson("/api/matches/{$match->id}/messages", [
            'body' => 'Message a signaler',
        ])->assertCreated()->json('id');

        Sanctum::actingAs($finder);

        $this->postJson("/api/matches/{$match->id}/messages/{$messageId}/report", [
            'reason' => 'Comportement suspect',
        ])->assertCreated()
            ->assertJsonPath('type', 'COMPORTEMENT_ABUSIF');

        $this->assertDatabaseHas('claims', [
            'reporter_id' => $finder->id,
            'related_match_id' => $match->id,
            'type' => 'COMPORTEMENT_ABUSIF',
        ]);
        $this->assertDatabaseHas('moderation_events', [
            'message_id' => $messageId,
            'decision' => ModerationEvent::DECISION_FLAG,
        ]);
    }

    public function test_messages_endpoint_returns_the_latest_page(): void
    {
        [$match, $owner] = $this->makeMatch();
        $base = now()->startOfMinute();

        foreach (range(0, 54) as $index) {
            DB::table('messages')->insert([
                'id' => (string) Str::uuid(),
                'match_id' => $match->id,
                'sender_id' => $owner->id,
                'body' => 'message-'.$index,
                'status' => Message::STATUS_APPROVED,
                'created_at' => $base->copy()->subMinutes(55 - $index)->toDateTimeString(),
            ]);
        }

        Sanctum::actingAs($owner);

        $this->getJson("/api/matches/{$match->id}/messages?limit=10")
            ->assertOk()
            ->assertJsonCount(10)
            ->assertJsonPath('0.body', 'message-45')
            ->assertJsonPath('9.body', 'message-54');

        $before = urlencode($base->copy()->subMinutes(10)->toIso8601String());

        $this->getJson("/api/matches/{$match->id}/messages?limit=10&before={$before}")
            ->assertOk()
            ->assertJsonCount(10)
            ->assertJsonPath('0.body', 'message-35')
            ->assertJsonPath('9.body', 'message-44');
    }

    public function test_read_receipt_is_broadcast_and_updates_unread_count(): void
    {
        [$match, $owner, $finder] = $this->makeMatch();
        Event::fake([MessageSent::class, MessagesRead::class]);

        Sanctum::actingAs($owner);
        $messageId = $this->postJson("/api/matches/{$match->id}/messages", [
            'body' => 'A bientot',
        ])->assertCreated()->json('id');

        Sanctum::actingAs($finder);
        $this->getJson('/api/matches')
            ->assertOk()
            ->assertJsonPath('0.unread_count', 1)
            ->assertJsonPath('0.last_message', 'A bientot')
            ->assertJsonPath('0.can_chat', true);

        $this->postJson("/api/matches/{$match->id}/messages/read")
            ->assertOk()
            ->assertJsonPath('updated', 1);

        Event::assertDispatched(
            MessagesRead::class,
            fn (MessagesRead $event) => $event->messageIds === [$messageId]
                && $event->reader->id === $finder->id,
        );

        $this->getJson('/api/matches')
            ->assertOk()
            ->assertJsonPath('0.unread_count', 0);
    }

    public function test_only_the_owner_can_answer_the_verification(): void
    {
        [$match, $owner, $finder] = $this->makeMatch(ItemMatch::STATUS_PENDING);

        Sanctum::actingAs($finder);
        $this->postJson("/api/matches/{$match->id}/answer", ['answer' => 'YES'])
            ->assertForbidden();

        Sanctum::actingAs($owner);
        $this->postJson("/api/matches/{$match->id}/answer", ['answer' => 'YES'])
            ->assertOk()
            ->assertJsonPath('status', ItemMatch::STATUS_VERIFIED)
            ->assertJsonPath('can_chat', true);
    }

    /**
     * @return array{0: ItemMatch, 1: User, 2: User}
     */
    private function makeMatch(string $status = ItemMatch::STATUS_VERIFIED): array
    {
        $owner = User::factory()->create([
            'phone_verified' => true,
            'trust_score' => 50,
        ]);
        $finder = User::factory()->create([
            'phone_verified' => true,
            'trust_score' => 50,
        ]);

        $lost = Item::create([
            'user_id' => $owner->id,
            'type' => Item::TYPE_LOST,
            'category' => 'sac',
            'title' => 'Sac perdu',
            'description' => 'Sac noir perdu au centre-ville.',
            'occurred_at' => now()->subDay(),
        ]);

        $found = Item::create([
            'user_id' => $finder->id,
            'type' => Item::TYPE_FOUND,
            'category' => 'sac',
            'title' => 'Sac trouve',
            'description' => 'Sac noir trouve au centre-ville.',
            'occurred_at' => now()->subDay(),
        ]);

        $match = ItemMatch::create([
            'lost_item_id' => $lost->id,
            'found_item_id' => $found->id,
            'global_score' => 85,
            'status' => $status,
        ]);

        return [$match, $owner, $finder];
    }
}
