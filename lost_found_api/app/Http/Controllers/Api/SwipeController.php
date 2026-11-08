<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Item;
use App\Models\ItemMatch;
use App\Models\SwipeDecision;
use App\Services\Ai\SwipeAiService;
use App\Services\MatchingService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Validation\Rule;

/**
 * Module Tinder Cards - deck de correspondances, analyse IA et glissements.
 *
 * Le deck est reserve aux annonces perdues de l'utilisateur : c'est lui qui
 * peut dire "c'est à moi". Un glissement a droite repond YES au parcours de
 * verification existant (MatchController::answer), un glissement a gauche
 * repond NO. L'historique est conserve dans swipe_decisions pour ne pas
 * reproposer la meme carte.
 */
class SwipeController extends Controller
{
    public function deck(
        Request $request,
        MatchingService $matching,
        SwipeAiService $ai
    ): JsonResponse {
        $user = $request->user();

        $lostItems = Item::query()
            ->where('user_id', $user->id)
            ->where('type', Item::TYPE_LOST)
            ->where('status', 'ACTIVE')
            ->get();

        $matchIds = [];
        foreach ($lostItems as $lost) {
            foreach ($matching->findMatches($lost) as $result) {
                $matchIds[] = $result['match']->id;
            }
        }
        $matchIds = array_values(array_unique($matchIds));

        $decided = SwipeDecision::query()
            ->where('user_id', $user->id)
            ->whereIn('item_match_id', $matchIds)
            ->pluck('item_match_id')
            ->all();

        $matches = ItemMatch::query()
            ->with(['lostItem.user', 'foundItem.user'])
            ->whereIn('id', $matchIds)
            ->whereNotIn('id', $decided)
            ->orderByDesc('global_score')
            ->limit((int) config('swipe_ai.max_candidates', 30))
            ->get()
            // Une reponse donnee depuis la fiche detaillee ne doit pas non plus
            // reapparaitre dans le deck.
            ->reject(fn (ItemMatch $match) => isset($match->decision['answer']));

        return response()->json([
            'candidates' => $matches
                ->map(fn (ItemMatch $match) => $this->candidateJson($match, $ai))
                ->values(),
            'ai_enabled' => $ai->enabled(),
            'lost_items_count' => $lostItems->count(),
            'message' => $lostItems->isEmpty()
                ? 'Publiez une annonce perdue pour recevoir des cartes personnalisées.'
                : null,
        ]);
    }

    /** Analyse IA detaillee d'une correspondance (mise en cache). */
    public function insight(
        Request $request,
        ItemMatch $match,
        SwipeAiService $ai
    ): JsonResponse {
        $this->authorizeParticipant($request, $match);

        $cacheKey = sprintf(
            'swipe_ai:%s:%s',
            $match->id,
            $match->updated_at?->timestamp ?? 0
        );

        $insight = Cache::remember(
            $cacheKey,
            (int) config('swipe_ai.cache_ttl', 3600),
            fn () => $ai->analyze($match)
        );

        return response()->json([
            'insight' => $insight,
            'ai_enabled' => $ai->enabled(),
        ]);
    }

    /**
     * Enregistre un glissement. LIKE = YES, PASS = NO dans le parcours de
     * verification existant, afin que la fiche et le deck restent coherents.
     */
    public function decide(
        Request $request,
        ItemMatch $match
    ): JsonResponse {
        $this->authorizeOwner($request, $match);

        $data = $request->validate([
            'direction' => ['required', Rule::in(['LIKE', 'PASS'])],
            'ai_confidence' => ['nullable', 'integer', 'between:0,100'],
        ]);

        $answer = $data['direction'] === SwipeDecision::DIRECTION_LIKE
            ? 'YES'
            : 'NO';

        $match->update([
            // On conserve "decision.engine" (verdict du moteur) : la reponse
            // utilisateur vit dans "decision.answer".
            'decision' => array_merge($match->decision ?? [], ['answer' => $answer]),
            'verification_attempts' => $match->verification_attempts + 1,
        ]);

        if ($answer === 'YES' && $match->status === ItemMatch::STATUS_PENDING) {
            $match->update([
                'status' => ItemMatch::STATUS_VERIFIED,
                'verified_at' => now(),
            ]);
        }

        SwipeDecision::updateOrCreate(
            [
                'user_id' => $request->user()->id,
                'item_match_id' => $match->id,
            ],
            [
                'direction' => $data['direction'],
                'ai_confidence' => $data['ai_confidence'] ?? null,
                'metadata' => [
                    'source' => 'tinder_cards',
                    'score_global' => $match->global_score,
                ],
            ]
        );

        return response()->json([
            'status' => 'ok',
            'direction' => $data['direction'],
            'answer' => $answer,
            'match_id' => $match->id,
        ]);
    }

    /** Contrat JSON partage avec lost_found_ai/lib/data/models/swipe_candidate.dart. */
    private function candidateJson(ItemMatch $match, SwipeAiService $ai): array
    {
        $match->loadMissing(['lostItem.user', 'foundItem.user']);

        return [
            'id' => $match->id,
            'status' => $match->status,
            'created_at' => $match->created_at?->toIso8601String(),
            'distance_km' => $ai->distanceKm($match),
            'scores' => [
                'image' => $match->image_score,
                'location' => $match->location_score,
                'time' => $match->time_score,
                'text' => $match->text_score,
                'global' => $match->global_score,
            ],
            'lost_item' => $this->itemJson($match->lostItem),
            'found_item' => $this->itemJson($match->foundItem),
            'ai' => $ai->preview($match),
        ];
    }

    /** Le secret_detail n'est jamais expose : il sert a la verification formelle. */
    private function itemJson(?Item $item): ?array
    {
        if (! $item) {
            return null;
        }

        $item->loadMissing('user');

        return [
            'id' => $item->id,
            'type' => $item->type,
            'category' => $item->category,
            'title' => $item->title,
            'description' => $item->description,
            'place_label' => $item->place_label,
            'latitude' => $item->latitude,
            'longitude' => $item->longitude,
            'occurred_at' => $item->occurred_at?->toIso8601String(),
            'status' => $item->status,
            'user' => $item->user ? [
                'id' => $item->user->id,
                'name' => $item->user->name,
                'trust_score' => $item->user->trust_score,
                'recovered_count' => $item->user->recovered_count,
            ] : null,
        ];
    }

    private function authorizeParticipant(Request $request, ItemMatch $match): void
    {
        $match->loadMissing(['lostItem', 'foundItem']);
        $userId = $request->user()->id;

        $isOwner = $match->lostItem?->user_id === $userId;
        $isFinder = $match->foundItem?->user_id === $userId;

        abort_unless(
            $isOwner || $isFinder,
            403,
            'Cette correspondance ne concerne pas votre compte.'
        );
    }

    /**
     * Seul le proprietaire de l'objet perdu peut repondre sur une carte :
     * le trouveur ne doit jamais pouvoir valider "c'est a moi" a sa place.
     */
    private function authorizeOwner(Request $request, ItemMatch $match): void
    {
        $match->loadMissing('lostItem');

        abort_unless(
            $match->lostItem?->user_id === $request->user()->id,
            403,
            'Seul le proprietaire de l\'objet perdu peut repondre sur cette carte.'
        );
    }
}
