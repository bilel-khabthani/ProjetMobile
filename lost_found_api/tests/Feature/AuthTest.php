<?php

namespace Tests\Feature;

use App\Mail\ResetPasswordOtpMail;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Mail;
use Tests\TestCase;

class AuthTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        config([
            'services.google.client_id' => 'test-web-client.apps.googleusercontent.com',
        ]);
    }

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

    public function test_google_login_requires_id_token(): void
    {
        $this->postJson('/api/auth/google', [
            'email' => 'charlie.google@gmail.com',
        ])->assertUnprocessable()
            ->assertJsonValidationErrors('id_token');
    }

    public function test_google_login_rejects_invalid_token(): void
    {
        Http::fake([
            'https://oauth2.googleapis.com/tokeninfo*' => Http::response([
                'error' => 'invalid_token',
            ], 400),
        ]);

        $this->postJson('/api/auth/google', [
            'id_token' => 'invalid-token',
        ])->assertUnauthorized();
    }

    public function test_google_login_rejects_token_for_another_client(): void
    {
        Http::fake([
            'https://oauth2.googleapis.com/tokeninfo*' => Http::response([
                'iss' => 'https://accounts.google.com',
                'aud' => 'another-client.apps.googleusercontent.com',
                'email' => 'charlie.google@gmail.com',
                'email_verified' => 'true',
                'sub' => 'google_sub_123456789',
            ]),
        ]);

        $this->postJson('/api/auth/google', [
            'id_token' => 'valid-token-for-another-app',
        ])->assertUnauthorized();
    }

    public function test_google_login_rejects_when_client_id_is_not_configured(): void
    {
        config(['services.google.client_id' => null]);

        Http::fake([
            'https://oauth2.googleapis.com/tokeninfo*' => Http::response([
                'iss' => 'https://accounts.google.com',
                'aud' => 'test-web-client.apps.googleusercontent.com',
                'email' => 'charlie.google@gmail.com',
                'email_verified' => 'true',
                'sub' => 'google_sub_123456789',
            ]),
        ]);

        $this->postJson('/api/auth/google', [
            'id_token' => 'valid-token',
        ])->assertUnauthorized();
    }

    public function test_google_login_accepts_google_workspace_email(): void
    {
        Http::fake([
            'https://oauth2.googleapis.com/tokeninfo*' => Http::response([
                'iss' => 'https://accounts.google.com',
                'aud' => config('services.google.client_id'),
                'email' => 'bilel.workspace@esprit.tn',
                'email_verified' => 'true',
                'sub' => 'google_sub_workspace',
                'name' => 'Bilel Workspace',
            ]),
        ]);

        $response = $this->postJson('/api/auth/google', [
            'id_token' => 'valid-workspace-token',
        ]);

        $response->assertOk()
            ->assertJsonPath('user.email', 'bilel.workspace@esprit.tn')
            ->assertJsonPath('user.google_id', 'google_sub_workspace');

        $this->assertDatabaseHas('users', [
            'email' => 'bilel.workspace@esprit.tn',
            'google_id' => 'google_sub_workspace',
        ]);
    }

    public function test_google_login_creates_new_user(): void
    {
        Http::fake([
            'https://oauth2.googleapis.com/tokeninfo*' => Http::response([
                'iss' => 'https://accounts.google.com',
                'aud' => config('services.google.client_id'),
                'email' => 'charlie.google@gmail.com',
                'email_verified' => 'true',
                'sub' => 'google_sub_123456789',
                'name' => 'Charlie Google',
                'picture' => 'https://example.com/avatar.jpg',
            ]),
        ]);

        $response = $this->postJson('/api/auth/google', [
            'id_token' => 'valid-token',
        ]);

        $response->assertOk()
            ->assertJsonStructure(['token', 'user', 'phone_verification_required'])
            ->assertJsonPath('user.email', 'charlie.google@gmail.com')
            ->assertJsonPath('user.google_id', 'google_sub_123456789')
            // La connexion Google cree un compte deja verifie (telephone de
            // demonstration synthétique) : aucun OTP n'est réclamé. Ce
            // contournement est volontaire pour la démonstration.
            ->assertJsonPath('phone_verification_required', false);

        $this->assertDatabaseHas('users', [
            'email' => 'charlie.google@gmail.com',
            'google_id' => 'google_sub_123456789',
        ]);
    }

    public function test_google_login_links_existing_user(): void
    {
        Http::fake([
            'https://oauth2.googleapis.com/tokeninfo*' => Http::response([
                'iss' => 'https://accounts.google.com',
                'aud' => config('services.google.client_id'),
                'email' => 'david@example.com',
                'email_verified' => 'true',
                'sub' => 'google_sub_999999',
                'name' => 'David Updated',
                'picture' => 'https://example.com/david.png',
            ]),
        ]);

        $existing = User::factory()->create([
            'email' => 'david@example.com',
            'google_id' => null,
            'phone' => '+33698765432',
            'phone_verified' => true,
        ]);

        $response = $this->postJson('/api/auth/google', [
            'id_token' => 'valid-token',
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

    public function test_forgot_password_in_local_sends_otp_to_unknown_address(): void
    {
        Mail::fake();

        $response = $this->postJson('/api/auth/forgot-password', [
            'email' => 'newcomer@example.com',
        ]);

        $response->assertOk()
            ->assertJsonPath('mail_sent', true)
            ->assertJsonPath('delivered_to', 'newcomer@example.com')
            ->assertJsonPath('account_exists', false)
            ->assertJsonStructure(['demo_otp']);

        Mail::assertSent(ResetPasswordOtpMail::class, function ($mail) {
            return $mail->hasTo('newcomer@example.com');
        });
    }

    public function test_forgot_password_redirects_campus_accounts_to_demo_inbox(): void
    {
        config(['mail.demo_redirect' => 'demo@example.com']);
        Mail::fake();

        $this->postJson('/api/auth/forgot-password', [
            'email' => 'student@campus.fr',
        ])->assertOk()
            ->assertJsonPath('delivered_to', 'demo@example.com');

        Mail::assertSent(ResetPasswordOtpMail::class, function ($mail) {
            return $mail->hasTo('demo@example.com');
        });
    }

    public function test_reset_password_on_unknown_address_creates_demo_account_in_local(): void
    {
        $otp = '654321';
        Cache::put('pwd:newcomer@example.com', $otp, now()->addMinutes(15));

        $response = $this->postJson('/api/auth/reset-password', [
            'email' => 'newcomer@example.com',
            'code' => $otp,
            'password' => 'newpassword123',
            'password_confirmation' => 'newpassword123',
        ]);

        $response->assertOk();

        $user = User::where('email', 'newcomer@example.com')->first();

        $this->assertNotNull($user);
        $this->assertTrue($user->phone_verified);
        $this->assertTrue(Hash::check('newpassword123', $user->password));
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
