<?php

namespace App\Http\Controllers\Api;

use App\Events\MessageSent;
use App\Events\MessagesRead;
use App\Http\Controllers\Controller;
use App\Http\Resources\MessageResource;
use App\Models\Claim;
use App\Models\Item;
use App\Models\ItemMatch;
use App\Models\Message;
use App\Models\ModerationEvent;
use App\Models\User;
use App\Services\Ai\TextAgreementService;
use App\Services\Moderation\ModerationResult;
use App\Services\Moderation\ModerationService;
use App\Services\TrustService;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

/**
 * Modules 3, 4 et 5 - Verification d'un match, restitution et chat.
 */
class MatchController extends Controller
{
    public function __construct(private readonly TrustService $trust) {}

    public function index(Request $request)
    {
        $viewer = $request->user();

        $matches = ItemMatch::query()
            ->with('lostItem.user', 'foundItem.user', 'latestMessage')
            ->withCount([
                'messages as unread_count' => fn ($query) => $query
                    ->where('sender_id', '!=', $viewer->id)
                    ->whereNull('read_at')
                    ->where('status', '!=', Message::STATUS_BLOCKED),
            ])
            ->whereHas('lostItem', fn ($q) => $q->where('user_id', $viewer->id))
            ->orWhereHas('foundItem', fn ($q) => $q->where('user_id', $viewer->id))
            ->latest()
            ->get();

        return response()->json(
            $matches
                ->map(fn (ItemMatch $match) => $this->toMatchJson($match, $request->user()))
                ->values()
        );
    }

    public function show(Request $request, ItemMatch $match)
    {
        Gate::authorize('view', $match);

        $viewer = $request->user();
        $match->load('lostItem.user', 'foundItem.user', 'latestMessage');
        $match->loadCount([
            'messages as unread_count' => fn ($query) => $query
                ->where('sender_id', '!=', $viewer->id)
                ->whereNull('read_at')
                ->where('status', '!=', Message::STATUS_BLOCKED),
        ]);

        return response()->json($this->toMatchJson($match, $viewer));
    }

    /**
     * Contrat JSON partage avec le client Flutter : les scores sont imbriques
     * sous "scores.dimensions" (photo / location / time / description) et les
     * annonces sous "lost_item" / "found_item", comme attendu par
     * lost_found_ai/lib/data/api_repository.dart.
     */
    protected function toMatchJson(ItemMatch $match, ?User $viewer = null): array
    {
        $lastMessage = $match->relationLoaded('latestMessage')
            ? $match->latestMessage
            : $match->latestMessage()->first();

        $unreadCount = $match->unread_count ?? 0;

        $chatMode = $viewer
            ? $this->trust->chatMode($viewer, $match)
            : TrustService::CHAT_MODE_LOCKED;
        $chatLockReason = $viewer && $chatMode === TrustService::CHAT_MODE_LOCKED
            ? $this->trust->chatLockReason($viewer, $match)
            : null;
        $coordinationRemaining = $viewer
            ? $this->trust->coordinationMessagesRemaining($viewer, $match)
            : null;

        return [
            'id' => $match->id,
            'status' => $match->status,
            'viewer_role' => $viewer && $match->foundItem?->user_id === $viewer->id
                ? 'finder'
                : 'owner',
            'decision' => $match->decision,
            'verification_attempts' => $match->verification_attempts,
            'verified_at' => $match->verified_at?->toIso8601String(),
            'owner_confirmed_at' => $match->owner_confirmed_at?->toIso8601String(),
            'finder_confirmed_at' => $match->finder_confirmed_at?->toIso8601String(),
            'created_at' => $match->created_at?->toIso8601String(),
            'can_chat' => $chatMode !== TrustService::CHAT_MODE_LOCKED,
            'chat_mode' => $chatMode,
            'coordination_messages_remaining' => $coordinationRemaining,
            'chat_locked_reason' => $chatLockReason,
            'last_message' => $lastMessage?->body,
            'last_message_at' => $lastMessage?->created_at?->toIso8601String(),
            'last_message_is_mine' => $viewer !== null
                && $lastMessage?->sender_id === $viewer->id,
            'unread_count' => (int) $unreadCount,
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
            'image_url' => $item->image_path ? '/storage/'.$item->image_path : null,
            'user' => $item->user ? [
                'id' => $item->user->id,
                'name' => $item->user->name,
                'trust_score' => $item->user->trust_score,
                'recovered_count' => $item->user->recovered_count,
            ] : null,
        ];
    }

    /**
     * Module 2 - Verification : reponse libre du proprietaire comparee au
     * detail secret par le moteur d'accord textuel (exigence EF-06).
     *
     * Le trouveur ne peut jamais repondre a la place du proprietaire. Le champ
     * binaire `answer` reste accepte pour les glissements Tinder Cards ; le
     * formulaire de verification envoie `answer_text`.
     */
    public function answer(
        Request $request,
        ItemMatch $match,
        TextAgreementService $agreement
    ) {
        Gate::authorize('view', $match);

        $match->loadMissing('lostItem');

        if ($match->lostItem?->user_id !== $request->user()->id) {
            abort(403, 'Seul le propriétaire de l\'objet perdu peut répondre à la vérification.');
        }

        $data = $request->validate([
            'answer' => ['nullable', Rule::in(['YES', 'UNSURE', 'NO'])],
            'answer_text' => ['nullable', 'string', 'max:500'],
        ]);

        $answerText = trim((string) ($data['answer_text'] ?? ''));

        if ($answerText !== '') {
            $evaluation = $agreement->scoreAnswer(
                $answerText,
                $match->lostItem?->secret_detail,
            );
            $decision = $evaluation['decision'];
        } elseif (isset($data['answer'])) {
            $evaluation = [
                'score' => $data['answer'] === 'YES' ? 100 : 0,
                'decision' => $data['answer'],
                'matched' => [],
                'contradictions' => [],
                'neutral' => false,
            ];
            $decision = $data['answer'];
        } else {
            throw ValidationException::withMessages([
                'answer_text' => 'Repondez a la question de verification.',
            ]);
        }

        $match->update([
            // On conserve "decision.engine" (verdict du moteur) : la reponse
            // utilisateur vit dans "decision.answer".
            'decision' => array_merge($match->decision ?? [], [
                'answer' => $decision,
                'verification' => $evaluation,
            ]),
            'verification_attempts' => $match->verification_attempts + 1,
        ]);

        if ($decision === 'YES' && $match->status === ItemMatch::STATUS_PENDING) {
            $match->update(['status' => ItemMatch::STATUS_VERIFIED, 'verified_at' => now()]);
        }

        $payload = $this->toMatchJson(
            $match->fresh('lostItem.user', 'foundItem.user'),
            $request->user()
        );

        return response()->json([
            ...$payload,
            'verification' => $evaluation,
        ]);
    }

    /**
     * Module 5 - Double confirmation de restitution (exigence Must EF-09).
     * Le proprietaire et la personne ayant trouve l'objet doivent confirmer.
     * Le score de confiance n'est credite qu'apres les deux confirmations.
     */
    public function confirmRestitution(Request $request, ItemMatch $match, TrustService $trust)
    {
        Gate::authorize('view', $match);

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
                'match' => $this->toMatchJson($match->fresh('lostItem.user', 'foundItem.user'), $request->user()),
            ], 202);
        }

        return response()->json(
            $this->toMatchJson($match->fresh('lostItem.user', 'foundItem.user'), $request->user())
        );
    }

    /**
     * Chat securise : ouvert seulement aux deux parties, apres verification
     * du proprietaire et avec un score de confiance suffisant.
     */
    public function messages(Request $request, ItemMatch $match)
    {
        Gate::authorize('chat', $match);

        $data = $request->validate([
            'after' => ['nullable', 'date'],
            'before' => ['nullable', 'date'],
            'limit' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);

        $limit = (int) ($data['limit'] ?? 50);

        $query = Message::query()
            ->where('match_id', $match->id)
            ->where('status', '!=', Message::STATUS_BLOCKED)
            ->with('sender:id,name');

        if (! empty($data['after'])) {
            // Rafraichissement incremental : uniquement les nouveaux messages.
            $messages = $query
                ->where('created_at', '>', Carbon::parse($data['after']))
                ->orderBy('created_at')
                ->orderBy('id')
                ->limit($limit)
                ->get();
        } else {
            // Par defaut on renvoie les plus recents (puis on les remet dans
            // l'ordre chronologique attendu par le client). "before" permet
            // de remonter l'historique page par page.
            if (! empty($data['before'])) {
                $query->where('created_at', '<', Carbon::parse($data['before']));
            }

            $messages = $query
                ->orderByDesc('created_at')
                ->orderByDesc('id')
                ->limit($limit)
                ->get()
                ->reverse()
                ->values();
        }

        return response()->json(MessageResource::collection($messages)->resolve());
    }

    public function sendMessage(
        Request $request,
        ItemMatch $match,
        ModerationService $moderation,
    ) {
        Gate::authorize('chat', $match);

        $user = $request->user();

        if ($this->trust->chatMode($user, $match) === TrustService::CHAT_MODE_COORDINATION) {
            $remaining = $this->trust->coordinationMessagesRemaining($user, $match);

            if ($remaining !== null && $remaining <= 0) {
                return response()->json([
                    'message' => 'Vos 5 messages de coordination sont épuisés. '
                        .'Terminez la restitution ou contestez une sanction pour retrouver le chat.',
                    'code' => 'chat_quota_exhausted',
                    'coordination_messages_remaining' => 0,
                ], 422);
            }
        }

        $data = $request->validate(['body' => ['required', 'string', 'max:1000']]);
        $body = trim($data['body']);

        if ($body === '') {
            return response()->json(['message' => 'Le message est vide.'], 422);
        }

        $result = $moderation->moderate($body);

        if ($result->isBlocked()) {
            $this->recordModerationEvent($user->id, $match->id, $body, $result);
            $strikes = $this->applyStrike($user, $match, $result);

            return response()->json([
                'message' => 'Message bloqué : contenu inapproprié. Merci de rester courtois.',
                'code' => 'message_blocked',
                'strikes' => $strikes,
            ], 422);
        }

        $message = Message::create([
            'match_id' => $match->id,
            'sender_id' => $user->id,
            'body' => $body,
            'status' => Message::STATUS_APPROVED,
            'moderation_categories' => $result->categories ?: null,
            'moderation_scores' => $result->scores ?: null,
            'moderation_provider' => $result->provider,
        ]);

        $message->load('sender:id,name');

        try {
            broadcast(new MessageSent($message));
        } catch (\Throwable $exception) {
            // Le chat doit rester disponible meme si Reverb est indisponible.
            Log::warning('Message broadcast failed.', ['exception' => $exception::class]);
        }

        return response()->json((new MessageResource($message))->resolve(), 201);
    }

    /** Marque comme lus tous les messages recus dans cette correspondance. */
    public function markMessagesRead(Request $request, ItemMatch $match)
    {
        Gate::authorize('chat', $match);

        $readAt = now();
        $messageIds = Message::query()
            ->where('match_id', $match->id)
            ->where('sender_id', '!=', $request->user()->id)
            ->where('status', '!=', Message::STATUS_BLOCKED)
            ->whereNull('read_at')
            ->pluck('id');

        if ($messageIds->isEmpty()) {
            return response()->json(['updated' => 0]);
        }

        Message::query()->whereIn('id', $messageIds)->update(['read_at' => $readAt]);

        try {
            broadcast(new MessagesRead($match, $request->user(), $messageIds->all(), $readAt));
        } catch (\Throwable $exception) {
            Log::warning('Read receipt broadcast failed.', ['exception' => $exception::class]);
        }

        return response()->json(['updated' => $messageIds->count()]);
    }

    /**
     * Signalement d'un message : cree une reclamation tracable (CDC 6.4.5)
     * et un evenement de moderation pour l'arbitrage humain.
     */
    public function reportMessage(Request $request, ItemMatch $match, Message $message)
    {
        Gate::authorize('view', $match);

        if ($message->match_id !== $match->id) {
            abort(404);
        }

        $data = $request->validate([
            'reason' => ['nullable', 'string', 'max:500'],
        ]);

        ModerationEvent::create([
            'user_id' => $request->user()->id,
            'message_id' => $message->id,
            'match_id' => $match->id,
            'source' => ModerationEvent::SOURCE_CHAT,
            'decision' => ModerationEvent::DECISION_FLAG,
            'categories' => ['user_report'],
            'scores' => [],
            'text_hash' => hash('sha256', $message->body),
            'excerpt' => mb_substr($message->body, 0, 200),
        ]);

        $claim = Claim::create([
            'reporter_id' => $request->user()->id,
            'related_match_id' => $match->id,
            'type' => 'COMPORTEMENT_ABUSIF',
            'description' => trim(($data['reason'] ?? '')."\n\nMessage signalé : ".mb_substr($message->body, 0, 500)),
            'status' => Claim::STATUS_OPEN,
        ]);

        return response()->json($claim, 201);
    }

    private function recordModerationEvent(
        int $userId,
        string $matchId,
        string $body,
        ModerationResult $result,
    ): void {
        ModerationEvent::create([
            'user_id' => $userId,
            'match_id' => $matchId,
            'source' => ModerationEvent::SOURCE_CHAT,
            'decision' => ModerationEvent::DECISION_BLOCK,
            'categories' => $result->categories,
            'scores' => $result->scores,
            'text_hash' => hash('sha256', $body),
            'excerpt' => mb_substr($body, 0, 200),
        ]);
    }

    /**
     * Applique une sanction de score apres un blocage, selon la configuration.
     * Le nombre de strikes est renvoye pour informer le client.
     */
    private function applyStrike(User $user, ItemMatch $match, ModerationResult $result): int
    {
        $strikes = ModerationEvent::query()
            ->where('user_id', $user->id)
            ->where('source', ModerationEvent::SOURCE_CHAT)
            ->where('decision', ModerationEvent::DECISION_BLOCK)
            ->where('created_at', '>=', now()->subDay())
            ->count();

        $points = (int) config('moderation.strike_trust_points', 0);
        $threshold = max(1, (int) config('moderation.strike_threshold', 1));

        if ($points !== 0 && $strikes >= $threshold && ($threshold === 1 || $strikes === $threshold)) {
            $user->applyTrustDelta(
                $points,
                'MESSAGE_INAPPROPRIE',
                'Message bloqué par la modération ('.$result->provider.').',
                $match->id,
            );
        }

        return $strikes;
    }
}
