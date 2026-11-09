<?php

namespace App\Http\Resources;

use App\Models\Message;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Message
 */
class MessageResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'match_id' => $this->match_id,
            'body' => $this->body,
            'status' => $this->status,
            'created_at' => $this->created_at?->toIso8601String(),
            'read_at' => $this->read_at?->toIso8601String(),
            'is_mine' => $this->sender_id === $request->user()?->id,
            'sender' => [
                'id' => $this->sender?->id,
                'name' => $this->sender?->name,
                'initials' => $this->sender?->initials(),
            ],
        ];
    }
}
