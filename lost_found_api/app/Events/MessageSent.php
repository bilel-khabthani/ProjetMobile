<?php

namespace App\Events;

use App\Models\Message;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class MessageSent implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(public readonly Message $message) {}

    public function broadcastOn(): PrivateChannel
    {
        return new PrivateChannel('match.'.$this->message->match_id);
    }

    public function broadcastAs(): string
    {
        return 'message.sent';
    }

    /**
     * @return array<string, mixed>
     */
    public function broadcastWith(): array
    {
        $this->message->loadMissing('sender:id,name');

        return [
            'id' => $this->message->id,
            'match_id' => $this->message->match_id,
            'body' => $this->message->body,
            'status' => $this->message->status,
            'created_at' => $this->message->created_at?->toIso8601String(),
            'read_at' => null,
            'sender' => [
                'id' => $this->message->sender?->id,
                'name' => $this->message->sender?->name,
                'initials' => $this->message->sender?->initials(),
            ],
        ];
    }
}
