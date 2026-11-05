<?php

namespace App\Http\Controllers\Api;

use App\Models\Item;
use App\Models\Message;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

/**
 * Message Controller - Handles messaging between users
 * Enables communication about lost/found objects
 */
class MessageController extends Controller
{
    /**
     * Get all conversations for the authenticated user
     * Returns last message from each conversation with unread count
     */
    public function conversations(Request $request)
    {
        $user = $request->user();

        // Get unique conversations (all users this user has messaged or been messaged by)
        $conversationUserIds = Message::where('from_user_id', $user->id)
            ->orWhere('to_user_id', $user->id)
            ->selectRaw('CASE 
                WHEN from_user_id = ? THEN to_user_id 
                ELSE from_user_id 
            END as user_id', [$user->id])
            ->distinct()
            ->pluck('user_id');

        $conversations = User::whereIn('id', $conversationUserIds)
            ->get()
            ->map(function (User $otherUser) use ($user) {
                // Get last message in conversation
                $lastMessage = Message::where(function ($q) use ($user, $otherUser) {
                    $q->where('from_user_id', $user->id)->where('to_user_id', $otherUser->id)
                        ->orWhere('from_user_id', $otherUser->id)->where('to_user_id', $user->id);
                })
                    ->latest('created_at')
                    ->first();

                // Count unread messages from this user
                $unreadCount = Message::where('from_user_id', $otherUser->id)
                    ->where('to_user_id', $user->id)
                    ->where('is_read', false)
                    ->count();

                return [
                    'user' => $otherUser->only('id', 'name', 'phone', 'trust_score'),
                    'last_message' => $lastMessage ? [
                        'id' => $lastMessage->id,
                        'content' => $lastMessage->content,
                        'from_user_id' => $lastMessage->from_user_id,
                        'is_read' => $lastMessage->is_read,
                        'created_at' => $lastMessage->created_at,
                    ] : null,
                    'unread_count' => $unreadCount,
                ];
            })
            ->sortByDesc(fn ($conv) => $conv['last_message']?->created_at)
            ->values();

        return response()->json($conversations);
    }

    /**
     * Get messages in a conversation with a specific user
     * Marks messages as read
     */
    public function getMessages(Request $request, int $withUserId)
    {
        $user = $request->user();
        $limit = $request->input('limit', 50);
        $offset = $request->input('offset', 0);

        // Get messages between users
        $messages = Message::where(function ($q) use ($user, $withUserId) {
            $q->where('from_user_id', $user->id)->where('to_user_id', $withUserId)
                ->orWhere('from_user_id', $withUserId)->where('to_user_id', $user->id);
        })
            ->latest('created_at')
            ->offset($offset)
            ->limit($limit)
            ->get()
            ->map(function (Message $msg) {
                // Mark as read if recipient
                if ($msg->to_user_id === auth()->id()) {
                    $msg->markAsRead();
                }

                return [
                    'id' => $msg->id,
                    'from_user_id' => $msg->from_user_id,
                    'to_user_id' => $msg->to_user_id,
                    'content' => $msg->content,
                    'item_id' => $msg->item_id,
                    'is_read' => $msg->is_read,
                    'created_at' => $msg->created_at,
                ];
            })
            ->reverse()
            ->values();

        return response()->json($messages);
    }

    /**
     * Send a message to another user about an object
     */
    public function sendMessage(Request $request)
    {
        $validated = $request->validate([
            'to_user_id' => ['required', 'integer', 'exists:users,id'],
            'item_id' => ['required', 'uuid', 'exists:items,id'],
            'content' => ['required', 'string', 'max:500'],
        ]);

        $user = $request->user();

        // Prevent sending to self
        if ($validated['to_user_id'] === $user->id) {
            return response()->json(['error' => 'Cannot message yourself'], 422);
        }

        // Create message
        $message = Message::create([
            'from_user_id' => $user->id,
            'to_user_id' => $validated['to_user_id'],
            'item_id' => $validated['item_id'],
            'content' => $validated['content'],
            'is_read' => false,
        ]);

        return response()->json([
            'id' => $message->id,
            'from_user_id' => $message->from_user_id,
            'to_user_id' => $message->to_user_id,
            'content' => $message->content,
            'item_id' => $message->item_id,
            'is_read' => $message->is_read,
            'created_at' => $message->created_at,
        ], 201);
    }

    /**
     * Mark a message as read
     */
    public function markAsRead(Request $request, string $messageId)
    {
        $message = Message::findOrFail($messageId);

        // Only recipient can mark as read
        if ($message->to_user_id !== $request->user()->id) {
            return response()->json(['error' => 'Unauthorized'], 403);
        }

        $message->markAsRead();

        return response()->json([
            'id' => $message->id,
            'is_read' => $message->is_read,
            'read_at' => $message->read_at,
        ]);
    }

    /**
     * Get unread message count for the user
     */
    public function unreadCount(Request $request)
    {
        $count = Message::unreadCountFor($request->user()->id);
        return response()->json(['unread_count' => $count]);
    }
}
