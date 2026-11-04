<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Module 1 / CDC 6.1 et 6.4.3 : la verification du numero de telephone est
 * obligatoire avant toute utilisation des services (un numero = un compte).
 */
class EnsurePhoneVerified
{
    /**
     * Rejette les requetes d'un utilisateur dont le numero n'est pas verifie.
     * Le profil (/me, /trust/me) reste accessible afin de permettre la
     * verification depuis l'application et la consultation du score.
     */
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if ($user !== null && ! $user->phone_verified) {
            return response()->json([
                'message' => 'La verification du numero de telephone est requise.',
                'code' => 'phone_unverified',
            ], 403);
        }

        return $next($request);
    }
}
