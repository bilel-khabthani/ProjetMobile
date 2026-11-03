<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Hash;
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

        return response()->json([
            'token' => $user->createToken('mobile')->plainTextToken,
            'user' => $user,
            'phone_verification_required' => true,
            'demo_otp' => $this->storeOtp($data['phone']),
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

        return response()->json([
            'message' => 'Code de verification envoye.',
            'phone' => $data['phone'],
            'demo_otp' => $this->storeOtp($data['phone']),
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
     * Mot de passe oublie : envoie un code de reinitialisation (CDC 7.2,
     * aucune information sensible en clair). En demo le code est renvoye
     * dans la reponse, faute de passerelle SMS/e-mail branchee.
     */
    public function forgotPassword(Request $request)
    {
        $data = $request->validate([
            'email' => ['required', 'email', 'max:255'],
        ]);

        $user = User::where('email', $data['email'])->first();

        $response = [
            'message' => 'Si un compte existe, un code de reinitialisation a ete envoye.',
        ];

        if ($user !== null) {
            $code = (string) random_int(100000, 999999);
            Cache::put("pwd:{$user->email}", $code, now()->addMinutes(15));
            $response['demo_otp'] = $code;
        }

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

        $stored = Cache::get("pwd:{$data['email']}");

        if (! $stored || ! hash_equals((string) $stored, $data['code'])) {
            return response()->json(['message' => 'Code incorrect ou expire.'], 422);
        }

        // Le code n'est consomme qu'apres validation (voir otpVerify).
        Cache::forget("pwd:{$data['email']}");

        $user = User::where('email', $data['email'])->first();

        if (! $user) {
            return response()->json(['message' => 'Code incorrect ou expire.'], 422);
        }

        // Le cast "hashed" du modele hache la valeur ; toutes les sessions
        // existantes sont revoquees pour empecher l'usage de l'ancien acces.
        $user->update(['password' => $data['password']]);
        $user->tokens()->delete();

        return response()->json(['message' => 'Mot de passe reinitialise.']);
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
            $response['demo_otp'] = $this->storeOtp($user->phone);
        }

        return response()->json($response);
    }

    /**
     * Genere un code a six chiffres et le stocke en cache cinq minutes.
     * En demo (aucune passerelle SMS), le code est renvoye a l'appelant.
     */
    private function storeOtp(string $phone): string
    {
        $code = (string) random_int(100000, 999999);
        Cache::put("otp:{$phone}", $code, now()->addMinutes(5));

        return $code;
    }
}
