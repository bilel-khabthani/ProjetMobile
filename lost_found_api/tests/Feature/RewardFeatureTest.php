<?php

namespace Tests\Feature;

use App\Models\Reward;
use App\Models\User;
use App\Models\UserCoupon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Mail;
use Tests\TestCase;

class RewardFeatureTest extends TestCase
{
    protected User $user;

    protected function setUp(): void
    {
        parent::setUp();

        $this->user = User::factory()->create([
            'email' => 'test-student@campus.fr',
            'phone' => '+33611223344',
            'phone_verified' => true,
            'reward_points' => 200,
        ]);
    }

    public function test_user_can_view_rewards_catalog(): void
    {
        Reward::create([
            'title' => 'Livraison Gratuite Glovo',
            'partner_name' => 'Glovo Express',
            'partner_type' => 'DELIVERY',
            'description' => 'Livraison offerte',
            'points_cost' => 50,
            'discount_text' => 'Livraison 100% Offerte',
            'icon_name' => 'delivery_dining',
            'color_hex' => '#FFC244',
            'is_active' => true,
            'stock' => 10,
        ]);

        $response = $this->actingAs($this->user)->getJson('/api/rewards');

        $response->assertStatus(200)
            ->assertJsonFragment(['partner_name' => 'Glovo Express']);
    }

    public function test_user_can_view_wallet_and_history(): void
    {
        $response = $this->actingAs($this->user)->getJson('/api/rewards/wallet');

        $response->assertStatus(200)
            ->assertJsonStructure(['points', 'can_spin_free_today', 'spin_cost', 'history']);
    }

    public function test_user_can_redeem_reward_with_points(): void
    {
        Mail::fake();

        $reward = Reward::create([
            'title' => 'Bon Livraison Yassir',
            'partner_name' => 'Yassir Express',
            'partner_type' => 'DELIVERY',
            'description' => 'Livraison express',
            'points_cost' => 60,
            'discount_text' => 'Livraison Offerte',
            'icon_name' => 'local_shipping',
            'color_hex' => '#00A859',
            'is_active' => true,
            'stock' => 10,
        ]);

        $response = $this->actingAs($this->user)->postJson('/api/rewards/'.$reward->id.'/redeem');

        $response->assertStatus(201)
            ->assertJsonStructure(['message', 'coupon', 'new_balance']);

        $this->assertEquals(140, $this->user->fresh()->reward_points);
        $this->assertDatabaseHas('user_coupons', [
            'user_id' => $this->user->id,
            'partner_name' => 'Yassir Express',
        ]);
    }

    public function test_user_can_spin_wheel_and_win(): void
    {
        $response = $this->actingAs($this->user)->postJson('/api/rewards/wheel/spin');

        $response->assertStatus(200)
            ->assertJsonStructure([
                'prize_index',
                'prize' => ['index', 'label', 'type', 'color_hex'],
                'message',
                'new_balance',
            ]);
    }

    public function test_user_can_download_coupon_pdf(): void
    {
        $coupon = UserCoupon::create([
            'user_id' => $this->user->id,
            'title' => 'Bon Test PDF',
            'partner_name' => 'Glovo Express',
            'partner_type' => 'DELIVERY',
            'code' => 'TEST-PDF-99',
            'discount_text' => 'Livraison Offerte',
            'status' => 'ACTIVE',
            'source' => 'RESTITUTION',
            'expires_at' => now()->addDays(30),
        ]);

        $response = $this->actingAs($this->user)->get('/api/rewards/coupons/'.$coupon->id.'/pdf');

        $response->assertStatus(200)
            ->assertHeader('Content-Type', 'application/pdf');

        $this->assertStringStartsWith('%PDF-', $response->getContent());
    }

    public function test_user_can_send_coupon_by_email(): void
    {
        Mail::fake();

        $coupon = UserCoupon::create([
            'user_id' => $this->user->id,
            'title' => 'Bon Test Mail',
            'partner_name' => 'Glovo Express',
            'partner_type' => 'DELIVERY',
            'code' => 'TEST-MAIL-88',
            'discount_text' => 'Livraison Offerte',
            'status' => 'ACTIVE',
            'source' => 'RESTITUTION',
            'expires_at' => now()->addDays(30),
        ]);

        $response = $this->actingAs($this->user)->postJson('/api/rewards/coupons/'.$coupon->id.'/send-email');

        $response->assertStatus(200)
            ->assertJson(['status' => 'sent']);
    }
}

