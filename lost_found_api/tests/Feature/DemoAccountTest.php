<?php

namespace Tests\Feature;

use App\Models\User;
use Database\Seeders\DemoSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Verifie que les comptes de demonstration restent utilisables tels quels :
 * numero deja verifie, connexion sans code et deck Tinder Cards alimente.
 */
class DemoAccountTest extends TestCase
{
    use RefreshDatabase;

    public function test_demo_account_logs_in_without_phone_verification(): void
    {
        $this->seed(DemoSeeder::class);

        $user = User::query()->where('email', 'amina@campus.fr')->firstOrFail();

        $this->assertTrue((bool) $user->phone_verified);

        $response = $this->postJson('/api/auth/login', [
            'email' => 'amina@campus.fr',
            'password' => DemoSeeder::DEMO_PASSWORD,
        ]);

        $response->assertOk()
            ->assertJsonPath('user.email', 'amina@campus.fr')
            ->assertJsonPath('user.phone_verified', true);
    }

    public function test_demo_account_has_a_ready_swipe_deck(): void
    {
        $this->seed(DemoSeeder::class);

        $user = User::query()->where('email', 'amina@campus.fr')->firstOrFail();

        $response = $this->actingAs($user, 'sanctum')->getJson('/api/swipe/deck');

        $response->assertOk()
            ->assertJsonPath('lost_items_count', 1);

        $this->assertNotEmpty($response->json('candidates'));
    }
}
