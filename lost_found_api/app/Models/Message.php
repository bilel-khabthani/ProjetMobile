<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

#[Fillable([
    'match_id', 'sender_id', 'body', 'status', 'moderation_categories',
    'moderation_scores', 'moderation_provider', 'read_at',
])]
class Message extends Model
{
    use HasUuids, SoftDeletes;

    protected $keyType = 'string';

    public $incrementing = false;

    public const CREATED_AT = 'created_at';

    public const UPDATED_AT = null;

    public const STATUS_APPROVED = 'APPROVED';

    public const STATUS_BLOCKED = 'BLOCKED';

    public const STATUS_FLAGGED = 'FLAGGED';

    protected function casts(): array
    {
        return [
            'moderation_categories' => 'array',
            'moderation_scores' => 'array',
            'read_at' => 'datetime',
            'deleted_at' => 'datetime',
        ];
    }

    public function match(): BelongsTo
    {
        return $this->belongsTo(ItemMatch::class);
    }

    public function sender(): BelongsTo
    {
        return $this->belongsTo(User::class, 'sender_id');
    }

    public function moderationEvents(): HasMany
    {
        return $this->hasMany(ModerationEvent::class);
    }
}
