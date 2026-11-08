<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Claim;
use App\Services\TrustService;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/**
 * Module 5 - Reclamations (CDC section 6.4.5).
 * Toute reclamation est tracee, repondue, puis arbitree. Le systeme
 * n'applique jamais de sanction sans validation humaine.
 */
class ClaimController extends Controller
{
    public function index(Request $request)
    {
        $claims = Claim::query()
            ->where('reporter_id', $request->user()->id)
            ->with('respondent:id,name')
            ->latest()
            ->get();

        return response()->json($claims);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'type' => ['required', Rule::in([
                'OBJET_NON_REMIS',
                'CONTESTATION_PROPRIETE',
                'SUSPICION_FRAUDE',
                'COMPORTEMENT_ABUSIF',
                'ERREUR_CORRESPONDANCE',
            ])],
            'description' => ['required', 'string', 'max:2000'],
            'related_match_id' => ['nullable', 'uuid'],
            'related_item_id' => ['nullable', 'uuid'],
        ]);

        $claim = Claim::create([
            ...$data,
            'reporter_id' => $request->user()->id,
            'status' => Claim::STATUS_OPEN,
        ]);

        return response()->json($claim, 201);
    }

    /** Reponse apportee : le cycle garantit qu'une reponse est toujours donnee. */
    public function respond(Request $request, Claim $claim)
    {
        $data = $request->validate(['response_text' => ['required', 'string', 'max:2000']]);

        $claim->update([
            'response_text' => $data['response_text'],
            'status' => Claim::STATUS_ANSWERED,
            'responded_at' => now(),
            'respondent_id' => $claim->respondent_id ?? $request->user()->id,
        ]);

        return response()->json($claim);
    }

    /**
     * Escalade vers un administrateur. Seul l'admin peut ensuite resoudre,
     * et une reclamation fondee declenche un evenement de score.
     */
    public function escalate(Claim $claim)
    {
        $claim->update(['status' => Claim::STATUS_ESCALATED]);

        return response()->json($claim);
    }

    /** Arbitrage humain : resolution + eventement de score eventuel. */
    public function resolve(Request $request, Claim $claim, TrustService $trust)
    {
        $data = $request->validate([
            'resolution' => ['required', Rule::in(['RESOLUE', 'CLOTUREE'])],
            'founded' => ['required', 'boolean'],
            'sanction_type' => ['nullable', Rule::in(array_keys(TrustService::POINTS))],
        ]);

        if ($data['founded'] && ! $data['sanction_type']) {
            return response()->json([
                'message' => 'Une reclamation fondee doit correspondre a un type de sanction.',
            ], 422);
        }

        if ($data['founded'] && $claim->respondent) {
            $trust->sanction($claim->respondent, $data['sanction_type']);
        }

        $claim->update([
            'status' => $data['resolution'],
            'resolved_at' => now(),
        ]);

        return response()->json($claim->fresh('respondent'));
    }
}
