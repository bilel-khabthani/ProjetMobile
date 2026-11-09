<?php

namespace Tests\Feature;

use App\Mail\ResetPasswordOtpMail;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Tests\TestCase;

class AuthTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_register(): void
    {
        $response = $this->postJson('/api/auth/register', [
            'name' => 'Alice Martin',
            'email' => 'alice@example.com',
            'phone' => '+33612345678',
            'password' => 'secret1234',
        ]);

        $response->assertCreated()
            ->assertJsonStructure(['token', 'user', 'phone_verification_required', 'demo_otp'])
            ->assertJsonPath('user.email', 'alice@example.com')
            ->assertJsonPath('phone_verification_required', true);

        $this->assertDatabaseHas('users', [
            'email' => 'alice@example.com',
            'phone' => '+33612345678',
            'phone_verified' => false,
        ]);
    }

    public function test_user_can_login_with_valid_credentials(): void
    {
        $user = User::factory()->create([
            'email' => 'bob@example.com',
            'password' => 'password123',
        ]);

        $response = $this->postJson('/api/auth/login', [
            'email' => 'bob@example.com',
            'password' => 'password123',
        ]);

        $response->assertOk()
            ->assertJsonStructure(['token', 'user'])
            ->assertJsonPath('user.email', 'bob@example.com');
    }

    public function test_user_cannot_login_with_invalid_credentials(): void
    {
        User::factory()->create([
            'email' => 'bob@example.com',
            'password' => 'password123',
        ]);

        $response = $this->postJson('/api/auth/login', [
            'email' => 'bob@example.com',
            'password' => 'wrong_password',
        ]);

        $response->assertUnauthorized()
            ->assertJsonPath('message', 'Identifiants invalides.');
    }

    public function test_google_login_creates_new_user(): void
    {
        $response = $this->postJson('/api/auth/google', [
            'email' => 'charlie.google@gmail.com',
            'name' => 'Charlie Google',
            'google_id' => 'google_sub_123456789',
            'avatar' => 'https://example.com/avatar.jpg',
        ]);

        $response->assertOk()
            ->assertJsonStructure(['token', 'user', 'phone_verification_required'])
            ->assertJsonPath('user.email', 'charlie.google@gmail.com')
            ->assertJsonPath('user.google_id', 'google_sub_123456789')
            // Un compte Google est deja verifie par Google : aucun OTP
            // supplementaire ne doit bloquer l'acces aux services.
            ->assertJsonPath('phone_verification_required', false);

        $this->assertDatabaseHas('users', [
            'email' => 'charlie.google@gmail.com',
            'google_id' => 'google_sub_123456789',
            'phone_verified' => true,
        ]);
    }

    public function test_google_login_links_existing_user(): void
    {
        $existing = User::factory()->create([
            'email' => 'david@example.com',
            'google_id' => null,
            'phone' => '+33698765432',
            'phone_verified' => true,
        ]);

        $response = $this->postJson('/api/auth/google', [
            'email' => 'david@example.com',
            'name' => 'David Updated',
            'google_id' => 'google_sub_999999',
            'avatar' => 'https://example.com/david.png',
        ]);

        $response->assertOk()
            ->assertJsonPath('user.email', 'david@example.com')
            ->assertJsonPath('user.google_id', 'google_sub_999999')
            ->assertJsonPath('phone_verification_required', false);

        $this->assertDatabaseHas('users', [
            'id' => $existing->id,
            'google_id' => 'google_sub_999999',
        ]);
    }

    public function test_forgot_password_sends_otp_email_and_stores_in_cache(): void
    {
        Mail::fake();

        $user = User::factory()->create([
            'email' => 'eve@example.com',
        ]);

        $response = $this->postJson('/api/auth/forgot-password', [
            'email' => 'eve@example.com',
        ]);

        $response->assertOk()
            ->assertJsonStructure(['message', 'demo_otp']);

        Mail::assertSent(ResetPasswordOtpMail::class, function ($mail) {
            return $mail->hasTo('eve@example.com');
        });

        $this->assertTrue(Cache::has('pwd:eve@example.com'));
    }

    public function test_user_can_reset_password_with_valid_otp(): void
    {
        $user = User::factory()->create([
            'email' => 'frank@example.com',
            'password' => 'oldpassword',
        ]);

        $otp = '654321';
        Cache::put('pwd:frank@example.com', $otp, now()->addMinutes(15));

        $response = $this->postJson('/api/auth/reset-password', [
            'email' => 'frank@example.com',
            'code' => $otp,
            'password' => 'newpassword123',
            'password_confirmation' => 'newpassword123',
        ]);

        $response->assertOk()
            ->assertJsonPath('message', 'Mot de passe réinitialisé avec succès.');

        $this->assertTrue(Hash::check('newpassword123', $user->fresh()->password));
        $this->assertFalse(Cache::has('pwd:frank@example.com'));
    }

    public function test_reset_password_fails_with_invalid_otp(): void
    {
        User::factory()->create([
            'email' => 'grace@example.com',
            'password' => 'oldpassword',
        ]);

        Cache::put('pwd:grace@example.com', '111111', now()->addMinutes(15));

        $response = $this->postJson('/api/auth/reset-password', [
            'email' => 'grace@example.com',
            'code' => '999999',
            'password' => 'newpassword123',
            'password_confirmation' => 'newpassword123',
        ]);

        $response->assertStatus(422)
            ->assertJsonPath('message', 'Code de vérification incorrect ou expiré.');
    }
}
