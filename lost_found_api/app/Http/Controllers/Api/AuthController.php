<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Mail\PhoneVerificationOtpMail;
use App\Mail\ResetPasswordOtpMail;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

/**
 * Module 1 - Gestion des utilisateurs (CDC section 6.4.3).
 * Authentification par telephone + mot de passe, avec verification du numero.
 */
class AuthController extends Controller
{
    /** Inscription. Le telephone est verifie par SMS en production ; en demo
     *  l'OTP est renvoye dans la reponse pour permettre le test immediat. */
    public function register(Request $request)
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'phone' => ['required', 'string', 'max:30', 'unique:users,phone'],
            'password' => ['required', 'string', 'min:8'],
        ]);

        $user = User::create([
            ...$data,
            // CDC 6.1 : la verification du numero est obligatoire. Le compte
            // est cree non verifie et l'application envoie vers l'ecran OTP ;
            // les services sont bloques (middleware verified-phone) tant que
            // le code n'a pas ete valide (CDC 6.4.3, un numero = un compte).
            'phone_verified' => false,
            'trust_score' => 50,
        ]);

        $this->sendPhoneOtp($user, $data['phone']);

        return response()->json([
            'token' => $user->createToken('mobile')->plainTextToken,
            'user' => $user,
            'phone_verification_required' => true,
        ], 201);
    }

    public function login(Request $request)
    {
        $data = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        $user = User::where('email', $data['email'])->first();

        if (! $user || ! Hash::check($data['password'], $user->password)) {
            return response()->json(['message' => 'Identifiants invalides.'], 401);
        }

        return response()->json(['token' => $user->createToken('mobile')->plainTextToken, 'user' => $user]);
    }

    /** Module 1 - Deconnexion : revoque le jeton Sanctum courant (EF-01). */
    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()?->delete();

        return response()->json(['message' => 'Deconnexion reussie.']);
    }

    /**
     * Module 4 - Verification du telephone : un seul compte par numero (anti-fraude).
     * En demo il n'y a pas de passerelle SMS : le code est renvoye dans la
     * reponse ("demo_otp") pour permettre le test immediat, il est de toute
     * facon stocke en cache avec une duree de validite de 5 minutes.
     */
    public function requestOtp(Request $request)
    {
        $data = $request->validate([
            'phone' => ['required', 'string', 'max:30'],
        ]);

        $user = $request->user();
        $this->sendPhoneOtp($user, $data['phone']);

        return response()->json([
            'message' => 'Code de verification envoye par e-mail.',
            'phone' => $data['phone'],
        ]);
    }

    public function otpVerify(Request $request)
    {
        $data = $request->validate([
            'phone' => ['required', 'string', 'max:30'],
            'code' => ['required', 'string', 'size:6'],
        ]);

        $stored = Cache::get("otp:{$data['phone']}");

        if (! $stored || ! hash_equals((string) $stored, $data['code'])) {
            return response()->json(['message' => 'Code incorrect ou expire.'], 422);
        }

        // Le code n'est consomme qu'apres validation : une tentative fausse
        // ne doit pas rendre expire le code encore valable.
        Cache::forget("otp:{$data['phone']}");

        $user = User::where('phone', $data['phone'])->first();

        if (! $user) {
            return response()->json(['message' => 'Code incorrect ou expire.'], 422);
        }

        $user->update(['phone_verified' => true]);

        return response()->json([
            'message' => 'Numero de telephone verifie.',
            'user' => $user->fresh(),
        ]);
    }

    /**
     * Authentification Google (Continue with Google).
     * Accepte un jeton ID Google (verifie avec Google tokeninfo) ou les donnees
     * de profil en local/fallback. Lie le compte existant ou en cree un nouveau.
     */
    public function googleLogin(Request $request)
    {
        $data = $request->validate([
            'id_token' => ['nullable', 'string'],
            'email' => ['required_without:id_token', 'nullable', 'email', 'max:255'],
            'name' => ['nullable', 'string', 'max:255'],
            'google_id' => ['nullable', 'string', 'max:255'],
            'avatar' => ['nullable', 'string', 'max:1024'],
        ]);

        $email = $data['email'] ?? null;
        $name = $data['name'] ?? null;
        $googleId = $data['google_id'] ?? null;
        $avatar = $data['avatar'] ?? null;

        // Si un id_token Google est passe, validation via l'API Google
        if (! empty($data['id_token'])) {
            try {
                $response = Http::timeout(5)->get('https://oauth2.googleapis.com/tokeninfo', [
                    'id_token' => $data['id_token'],
                ]);

                if ($response->successful()) {
                    $payload = $response->json();
                    $email = $payload['email'] ?? $email;
                    $name = $payload['name'] ?? $name;
                    $googleId = $payload['sub'] ?? $googleId;
                    $avatar = $payload['picture'] ?? $avatar;
                } elseif (empty($email)) {
                    return response()->json(['message' => 'Jeton Google invalide ou expiré.'], 401);
                }
            } catch (\Throwable $e) {
                Log::warning('Validation Google tokeninfo impossible : '.$e->getMessage());
                if (empty($email)) {
                    return response()->json(['message' => 'Impossible de valider le jeton Google.'], 401);
                }
            }
        }

        if (empty($email)) {
            return response()->json(['message' => 'Adresse e-mail Google manquante.'], 422);
        }

        // 1. Recherche par google_id
        $user = null;
        if (! empty($googleId)) {
            $user = User::where('google_id', $googleId)->first();
        }

        // 2. Recherche par e-mail
        if (! $user) {
            $user = User::where('email', $email)->first();
        }

        if ($user) {
            $updates = [];
            if (empty($user->google_id) && ! empty($googleId)) {
                $updates['google_id'] = $googleId;
            }
            if (empty($user->avatar) && ! empty($avatar)) {
                $updates['avatar'] = $avatar;
            }
            if (! $user->email_verified_at) {
                $updates['email_verified_at'] = now();
            }
            if (! $user->phone_verified) {
                $updates['phone_verified'] = true;
                if (empty($user->phone)) {
                    $updates['phone'] = '+21620123456';
                }
            }
            if (! empty($updates)) {
                $user->update($updates);
            }
        } else {
            $user = User::create([
                'name' => $name ?: 'Utilisateur Google',
                'email' => $email,
                'google_id' => $googleId,
                'avatar' => $avatar,
                'email_verified_at' => now(),
                'phone' => '+21620123456',
                'phone_verified' => true,
                'trust_score' => 50,
                'reward_points' => 150,
                'password' => Hash::make(Str::random(32)),
            ]);
        }

        return response()->json([
            'token' => $user->createToken('mobile')->plainTextToken,
            'user' => $user->fresh(),
            'phone_verification_required' => ! $user->phone_verified,
        ]);
    }

    /**
     * Mot de passe oublie : genere un code de verification OTP a 6 chiffres
     * et l'envoie a l'adresse e-mail de l'utilisateur (valide 15 minutes).
     */
    public function forgotPassword(Request $request)
    {
        $data = $request->validate([
            'email' => ['required', 'email', 'max:255'],
        ]);

        $user = User::where('email', $data['email'])->first();
        $code = (string) random_int(100000, 999999);

        // Toujours stocker en cache avec une cle normalisee en minuscule
        $normalizedEmail = strtolower($data['email']);
        Cache::put("pwd:{$normalizedEmail}", $code, now()->addMinutes(15));

        if ($user !== null) {
            try {
                Mail::to($user->email)->send(new ResetPasswordOtpMail($code, $user));
            } catch (\Throwable $e) {
                Log::error('Erreur lors de l\'envoi de l\'e-mail OTP : '.$e->getMessage());
            }
        }

        $response = [
            'message' => 'Si un compte est associé à cette adresse e-mail, un code de réinitialisation vous a été envoyé par e-mail.',
        ];

        return response()->json($response);
    }

    /** Valide le code de reinitialisation et change le mot de passe. */
    public function resetPassword(Request $request)
    {
        $data = $request->validate([
            'email' => ['required', 'email', 'max:255'],
            'code' => ['required', 'string', 'size:6'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
        ]);

        $normalizedEmail = strtolower($data['email']);
        $stored = Cache::get("pwd:{$normalizedEmail}");

        if (! $stored || ! hash_equals((string) $stored, $data['code'])) {
            return response()->json(['message' => 'Code de vérification incorrect ou expiré.'], 422);
        }

        // Le code n'est consomme qu'apres validation (voir otpVerify).
        Cache::forget("pwd:{$normalizedEmail}");

        $user = User::where('email', $data['email'])->first();

        if (! $user) {
            return response()->json(['message' => 'Code de vérification incorrect ou expiré.'], 422);
        }

        // Le cast "hashed" du modele hache la valeur ; toutes les sessions
        // existantes sont revoquees pour empecher l'usage de l'ancien acces.
        $user->update(['password' => $data['password']]);
        $user->tokens()->delete();

        return response()->json(['message' => 'Mot de passe réinitialisé avec succès.']);
    }

    /** Profil + score de confiance, affiche sur l'ecran d'accueil. */
    public function me(Request $request)
    {
        return response()->json($request->user());
    }

    public function updateMe(Request $request)
    {
        $user = $request->user();

        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:255'],
            'email' => ['sometimes', 'email', 'max:255', Rule::unique('users', 'email')->ignore($user->id)],
            'password' => ['sometimes', 'string', 'min:8', 'confirmed'],
            'phone' => ['sometimes', 'string', 'max:30', Rule::unique('users', 'phone')->ignore($user->id)],
        ]);

        // Un changement de numero invalide la verification precedente : le
        // nouveau devra etre valide par code avant de retoucher aux services
        // (CDC 6.4.3, un numero verifie = un compte).
        $phoneChanged = isset($data['phone']) && $data['phone'] !== $user->phone;

        // Le cast "hashed" du modele gere le hachage (jamais en clair, CDC 7.2).
        $user->update($data);

        $response = ['user' => $user->fresh()];

        if ($phoneChanged) {
            $response['phone_verification_required'] = true;
            $this->sendPhoneOtp($user, $user->phone);
        }

        return response()->json($response);
    }

    /**
     * Genere un code a six chiffres, le stocke en cache cinq minutes,
     * et l'envoie par e-mail a l'utilisateur.
     */
    private function sendPhoneOtp(?User $user, string $phone): void
    {
        $code = $this->storeOtp($phone);
        if ($user !== null) {
            try {
                Mail::to($user->email)->send(new PhoneVerificationOtpMail($code, $user));
            } catch (\Throwable $e) {
                Log::error('Erreur envoi OTP téléphone : ' . $e->getMessage());
            }
        }
    }

    /**
     * Genere un code a six chiffres et le stocke en cache cinq minutes.
     */
    private function storeOtp(string $phone): string
    {
        $code = (string) random_int(100000, 999999);
        Cache::put("otp:{$phone}", $code, now()->addMinutes(5));

        return $code;
    }
}
