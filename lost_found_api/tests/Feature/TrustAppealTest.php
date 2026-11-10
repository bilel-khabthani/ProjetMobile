<?php

namespace Tests\Feature;

use App\Models\Claim;
use App\Models\TrustEvent;
use App\Models\User;
use App\Services\TrustService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use InvalidArgumentException;
use Tests\TestCase;

class TrustAppealTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_appeal_a_negative_sanction(): void
    {
        $user = $this->sanctionedUser();
        $event = $this->sanction($user);

        $this->actingAs($user, 'sanctum')
            ->postJson("/api/trust/events/{$event->id}/appeal", [
                'reason' => 'Ce message ne contenait aucune insulte.',
            ])
            ->assertCreated()
            ->assertJsonPath('type', Claim::TYPE_APPEL_SANCTION)
            ->assertJsonPath('status', Claim::STATUS_OPEN)
            ->assertJsonPath('related_trust_event_id', $event->id);

        $this->assertDatabaseHas('claims', [
            'reporter_id' => $user->id,
            'type' => Claim::TYPE_APPEL_SANCTION,
            'related_trust_event_id' => $event->id,
        ]);
    }

    public function test_user_cannot_appeal_someone_elses_sanction(): void
    {
        $owner = $this->sanctionedUser();
        $event = $this->sanction($owner);
        $outsider = $this->sanctionedUser();

        $this->actingAs($outsider, 'sanctum')
            ->postJson("/api/trust/events/{$event->id}/appeal")
            ->assertForbidden();
    }

    public function test_user_cannot_appeal_a_positive_event(): void
    {
        $user = $this->sanctionedUser();
        $event = TrustEvent::create([
            'user_id' => $user->id,
            'type' => 'RESTITUTION_CONFIRMEE',
            'points' => 15,
            'validated_by' => 'SYSTEME',
            'reason' => 'Restitution confirmee.',
        ]);

        $this->actingAs($user, 'sanctum')
            ->postJson("/api/trust/events/{$event->id}/appeal")
            ->assertStatus(422);
    }

    public function test_user_cannot_create_two_appeals_for_the_same_sanction(): void
    {
        $user = $this->sanctionedUser();
        $event = $this->sanction($user);

        $this->actingAs($user, 'sanctum')
            ->postJson("/api/trust/events/{$event->id}/appeal")
            ->assertCreated();

        $this->actingAs($user, 'sanctum')
            ->postJson("/api/trust/events/{$event->id}/appeal")
            ->assertStatus(422);

        $this->assertDatabaseCount('claims', 1);
    }

    public function test_reversal_restores_full_points_without_probation_halving(): void
    {
        $user = $this->sanctionedUser();
        $event = $this->sanction($user);

        $this->assertTrue($user->fresh()->isInProbation());

        $reversal = app(TrustService::class)->reverseSanction(
            $event->fresh(),
            'Sanction annulee.',
        );

        $this->assertSame(40, $user->fresh()->trust_score);
        $this->assertSame(5, $reversal->points);
        $this->assertSame($event->id, $reversal->reversal_of_id);

        $this->expectException(InvalidArgumentException::class);
        app(TrustService::class)->reverseSanction($event->fresh(), 'Deuxieme tentative.');
    }

    public function test_command_upholds_an_appeal_and_restores_the_score(): void
    {
        $user = $this->sanctionedUser();
        $event = $this->sanction($user);
        $claim = $this->appeal($user, $event);

        $this->artisan('trust:resolve-appeal', [
            'claim' => $claim->id,
            '--uphold' => true,
            '--note' => 'Message contextuel, pas insultant.',
            '--by' => 'admin@test.local',
        ])->assertExitCode(0);

        $this->assertSame(40, $user->fresh()->trust_score);
        $this->assertSame(Claim::STATUS_RESOLVED, $claim->fresh()->status);
        $this->assertDatabaseHas('trust_events', [
            'user_id' => $user->id,
            'type' => 'SANCTION_ANNULEE',
            'points' => 5,
            'reversal_of_id' => $event->id,
        ]);
    }

    public function test_command_rejects_an_appeal_without_changing_the_score(): void
    {
        $user = $this->sanctionedUser();
        $event = $this->sanction($user);
        $claim = $this->appeal($user, $event);

        $this->artisan('trust:resolve-appeal', [
            'claim' => $claim->id,
            '--reject' => true,
            '--note' => 'Le lexique confirme la sanction.',
        ])->assertExitCode(0);

        $this->assertSame(35, $user->fresh()->trust_score);
        $this->assertSame(Claim::STATUS_CLOSED, $claim->fresh()->status);
        $this->assertDatabaseMissing('trust_events', [
            'type' => 'SANCTION_ANNULEE',
        ]);
    }

    public function test_command_refuses_to_resolve_an_appeal_twice(): void
    {
        $user = $this->sanctionedUser();
        $event = $this->sanction($user);
        $claim = $this->appeal($user, $event);

        $this->artisan('trust:resolve-appeal', [
            'claim' => $claim->id,
            '--uphold' => true,
        ])->assertExitCode(0);

        $this->artisan('trust:resolve-appeal', [
            'claim' => $claim->id,
            '--reject' => true,
        ])->assertExitCode(1);

        $this->assertSame(40, $user->fresh()->trust_score);
    }

    public function test_trust_endpoint_exposes_appeal_status(): void
    {
        $user = $this->sanctionedUser();
        $event = $this->sanction($user);
        $this->appeal($user, $event);

        $this->actingAs($user, 'sanctum')
            ->getJson('/api/trust/me')
            ->assertOk()
            ->assertJsonPath('trust_score', 35)
            ->assertJsonPath('can_coordinate', true)
            ->assertJsonPath('min_score_to_coordinate', 30)
            ->assertJsonPath('events.0.id', $event->id)
            ->assertJsonPath('events.0.appeal_status', Claim::STATUS_OPEN)
            ->assertJsonPath('events.0.can_appeal', false);
    }

    private function sanctionedUser(): User
    {
        return User::factory()->create([
            'phone' => fake()->unique()->phoneNumber(),
            'phone_verified' => true,
            'trust_score' => 35,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function sanction(User $user): TrustEvent
    {
        return TrustEvent::create([
            'user_id' => $user->id,
            'type' => 'MESSAGE_INAPPROPRIE',
            'points' => -5,
            'validated_by' => 'SYSTEME',
            'reason' => 'Message bloque par la moderation (lexicon).',
        ]);
    }

    private function appeal(User $user, TrustEvent $event): Claim
    {
        return Claim::create([
            'reporter_id' => $user->id,
            'type' => Claim::TYPE_APPEL_SANCTION,
            'description' => 'Contestation de la sanction.',
            'related_trust_event_id' => $event->id,
            'status' => Claim::STATUS_OPEN,
        ]);
    }
}
