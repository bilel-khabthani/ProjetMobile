<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Claim;
use App\Models\TrustEvent;
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

        $appeals = Claim::query()
            ->where('reporter_id', $user->id)
            ->where('type', Claim::TYPE_APPEL_SANCTION)
            ->get()
            ->keyBy('related_trust_event_id');

        $events = $user->trustEvents()
            ->with('user:id,name')
            ->latest()
            ->limit(50)
            ->get()
            ->map(function (TrustEvent $event) use ($appeals): array {
                $appeal = $appeals->get($event->id);

                return [
                    ...$event->toArray(),
                    'appeal_status' => $appeal?->status,
                    'can_appeal' => $event->points < 0
                        && $appeal === null
                        && ! $event->isReversal(),
                ];
            });

        return response()->json([
            'trust_score' => $user->trust_score,
            'recovered_count' => $user->recovered_count,
            'in_probation' => $user->isInProbation(),
            'can_chat' => $user->trust_score >= TrustService::MIN_SCORE_TO_CHAT,
            'can_coordinate' => $user->phone_verified
                && $user->trust_score >= TrustService::MIN_SCORE_TO_COORDINATE
                && $user->trust_score < TrustService::MIN_SCORE_TO_CHAT,
            'min_score_to_chat' => TrustService::MIN_SCORE_TO_CHAT,
            'min_score_to_coordinate' => TrustService::MIN_SCORE_TO_COORDINATE,
            'scale' => ['min' => 0, 'max' => 100],
            'events' => $events,
        ]);
    }

    /** Un utilisateur conteste une sanction negative qui le concerne. */
    public function appeal(Request $request, TrustEvent $event)
    {
        $user = $request->user();

        abort_unless($event->user_id === $user->id, 403);

        if ($event->points >= 0) {
            return response()->json([
                'message' => 'Seule une sanction négative peut faire l\'objet d\'un appel.',
            ], 422);
        }

        $alreadyReversed = TrustEvent::query()
            ->where('reversal_of_id', $event->id)
            ->exists();

        if ($alreadyReversed) {
            return response()->json([
                'message' => 'Cette sanction a déjà été annulée.',
            ], 422);
        }

        $existing = Claim::query()
            ->where('reporter_id', $user->id)
            ->where('type', Claim::TYPE_APPEL_SANCTION)
            ->where('related_trust_event_id', $event->id)
            ->exists();

        if ($existing) {
            return response()->json([
                'message' => 'Un appel existe déjà pour cette sanction.',
            ], 422);
        }

        $data = $request->validate([
            'reason' => ['nullable', 'string', 'max:1000'],
        ]);

        $claim = Claim::create([
            'reporter_id' => $user->id,
            'type' => Claim::TYPE_APPEL_SANCTION,
            'description' => $data['reason']
                ?? 'Contestation de la sanction du '.$event->created_at?->format('d/m/Y H:i').'.',
            'related_trust_event_id' => $event->id,
            'status' => Claim::STATUS_OPEN,
        ]);

        return response()->json($claim, 201);
    }
}
