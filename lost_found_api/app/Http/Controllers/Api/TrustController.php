<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\TrustService;
use Illuminate\Http\Request;

/**
 * Module 4 - Consultation du score de confiance et de son historique.
 * Le score est en lecture seule pour l'utilisateur : aucune auto-declaration.
 */
class TrustController extends Controller
{
    public function me(Request $request)
    {
        $user = $request->user();

        $events = $user->trustEvents()
            ->with('user:id,name')
            ->latest()
            ->limit(50)
            ->get();

        return response()->json([
            'trust_score' => $user->trust_score,
            'recovered_count' => $user->recovered_count,
            'in_probation' => $user->isInProbation(),
            'can_chat' => $user->trust_score >= TrustService::MIN_SCORE_TO_CHAT,
            'scale' => ['min' => 0, 'max' => 100],
            'events' => $events,
        ]);
    }
}
