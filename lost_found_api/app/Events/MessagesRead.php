<?php

namespace App\Events;

use App\Models\ItemMatch;
use App\Models\User;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Carbon;

class MessagesRead implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    /**
     * @param  array<int, string>  $messageIds
     */
    public function __construct(
        public readonly ItemMatch $match,
        public readonly User $reader,
        public readonly array $messageIds,
        public readonly Carbon $readAt,
    ) {}

    public function broadcastOn(): PrivateChannel
    {
        return new PrivateChannel('match.'.$this->match->id);
    }

    public function broadcastAs(): string
    {
        return 'message.read';
    }

    /**
     * @return array<string, mixed>
     */
    public function broadcastWith(): array
    {
        return [
            'match_id' => $this->match->id,
            'reader_id' => $this->reader->id,
            'message_ids' => $this->messageIds,
            'read_at' => $this->readAt->toIso8601String(),
        ];
    }
}
