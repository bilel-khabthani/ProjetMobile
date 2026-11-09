<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable([
    'user_id', 'message_id', 'match_id', 'source', 'decision',
    'categories', 'scores', 'text_hash', 'excerpt',
])]
class ModerationEvent extends Model
{
    use HasUuids;

    protected $keyType = 'string';

    public $incrementing = false;

    public const DECISION_BLOCK = 'BLOCK';

    public const DECISION_FLAG = 'FLAG';

    public const DECISION_ALLOW = 'ALLOW';

    public const SOURCE_CHAT = 'CHAT';

    public const SOURCE_CLAIM = 'CLAIM';

    protected function casts(): array
    {
        return [
            'categories' => 'array',
            'scores' => 'array',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function message(): BelongsTo
    {
        return $this->belongsTo(Message::class);
    }

    public function match(): BelongsTo
    {
        return $this->belongsTo(ItemMatch::class, 'match_id');
    }
}
