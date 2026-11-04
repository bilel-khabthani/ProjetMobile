<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Item;
use App\Models\ItemMatch;
use App\Models\Message;
use App\Services\TrustService;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/**
 * Modules 3, 4 et 5 - Verification d'un match, restitution et chat.
 */
class MatchController extends Controller
{
    public function index(Request $request)
    {
        $matches = ItemMatch::query()
            ->with('lostItem.user', 'foundItem.user')
            ->whereHas('lostItem', fn ($q) => $q->where('user_id', $request->user()->id))
            ->orWhereHas('foundItem', fn ($q) => $q->where('user_id', $request->user()->id))
            ->latest()
            ->get();

        return response()->json(
            $matches->map(fn (ItemMatch $match) => $this->toMatchJson($match))->values()
        );
    }

    public function show(ItemMatch $match)
    {
        return response()->json($this->toMatchJson($match->load('lostItem.user', 'foundItem.user')));
    }

    /**
     * Contrat JSON partage avec le client Flutter : les scores sont imbriques
     * sous "scores.dimensions" (photo / location / time / description) et les
     * annonces sous "lost_item" / "found_item", comme attendu par
     * lost_found_ai/lib/data/api_repository.dart.
     */
    protected function toMatchJson(ItemMatch $match): array
    {
        return [
            'id' => $match->id,
            'status' => $match->status,
            'decision' => $match->decision,
            'verification_attempts' => $match->verification_attempts,
            'verified_at' => $match->verified_at?->toIso8601String(),
            'owner_confirmed_at' => $match->owner_confirmed_at?->toIso8601String(),
            'finder_confirmed_at' => $match->finder_confirmed_at?->toIso8601String(),
            'created_at' => $match->created_at?->toIso8601String(),
            'lost_item' => $this->itemJson($match->lostItem),
            'found_item' => $this->itemJson($match->foundItem),
            'scores' => [
                'dimensions' => [
                    'photo' => $match->image_score,
                    'location' => $match->location_score,
                    'time' => $match->time_score,
                    'description' => $match->text_score,
                ],
                'global' => $match->global_score,
            ],
        ];
    }

    /** Annonce serialisee pour le client. Le secret_detail n'est jamais expose :
     *  il sert uniquement a la verification formelle (Phase 2, EF-07). */
    protected function itemJson(?Item $item): ?array
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

    /**
     * Module 2 - Verification : reponse Oui / Incertain / Non (exigence EF-06).
     * L'apercu est non engageant, le score n'est pas modifie par la reponse.
     */
    public function answer(Request $request, ItemMatch $match)
    {
        $data = $request->validate([
            'answer' => ['required', Rule::in(['YES', 'UNSURE', 'NO'])],
        ]);

        $match->update([
            // On conserve "decision.engine" (verdict du moteur) : la reponse
            // utilisateur vit dans "decision.answer".
            'decision' => array_merge($match->decision ?? [], ['answer' => $data['answer']]),
            'verification_attempts' => $match->verification_attempts + 1,
        ]);

        if ($data['answer'] === 'YES' && $match->status === ItemMatch::STATUS_PENDING) {
            $match->update(['status' => ItemMatch::STATUS_VERIFIED, 'verified_at' => now()]);
        }

        return response()->json($this->toMatchJson($match->fresh('lostItem.user', 'foundItem.user')));
    }

    /**
     * Module 5 - Double confirmation de restitution (exigence Must EF-09).
     * Le proprietaire et la personne ayant trouve l'objet doivent confirmer.
     * Le score de confiance n'est credite qu'apres les deux confirmations.
     */
    public function confirmRestitution(Request $request, ItemMatch $match, TrustService $trust)
    {
        $role = $request->validate([
            'role' => ['required', Rule::in(['owner', 'finder'])],
        ])['role'];

        $user = $request->user();
        $isOwner = $match->lostItem->user_id === $user->id;
        $isFinder = $match->foundItem->user_id === $user->id;

        if (($role === 'owner' && ! $isOwner) || ($role === 'finder' && ! $isFinder)) {
            return response()->json(['message' => 'Ce role ne correspond pas a votre compte.'], 403);
        }

        if ($isOwner && $isFinder) {
            return response()->json([
                'message' => $trust->blockSelfMatch($match->lostItem->user_id, $match->foundItem->user_id),
            ], 422);
        }

        $match->update([
            $role === 'owner' ? 'owner_confirmed_at' : 'finder_confirmed_at' => now(),
        ]);

        $error = $trust->registerRestitution($match->fresh('lostItem.user'), $user);

        if ($error) {
            return response()->json([
                'message' => $error,
                'match' => $this->toMatchJson($match->fresh('lostItem.user', 'foundItem.user')),
            ], 202);
        }

        return response()->json($this->toMatchJson($match->fresh('lostItem.user', 'foundItem.user')));
    }

    /** Chat securise : ouvert seulement apres verification du proprietaire. */
    public function messages(Request $request, ItemMatch $match, TrustService $trust)
    {
        if (! $trust->canOpenChat($request->user(), $match)) {
            return response()->json([
                'message' => 'Le chat s\'ouvre apres verification du proprietaire et un score de confiance suffisant.',
            ], 403);
        }

        $messages = Message::where('match_id', $match->id)
            ->with('sender:id,name')
            ->orderBy('created_at')
            ->get();

        return response()->json($messages);
    }

    public function sendMessage(Request $request, ItemMatch $match, TrustService $trust)
    {
        if (! $trust->canOpenChat($request->user(), $match)) {
            return response()->json(['message' => 'Chat verrouille.'], 403);
        }

        $data = $request->validate(['body' => ['required', 'string', 'max:1000']]);

        $message = Message::create([
            'match_id' => $match->id,
            'sender_id' => $request->user()->id,
            'body' => $data['body'],
        ]);

        return response()->json($message->load('sender:id,name'), 201);
    }
}
