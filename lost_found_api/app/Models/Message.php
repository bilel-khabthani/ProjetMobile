<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['match_id', 'sender_id', 'body'])]
class Message extends Model
{
    use HasUuids;

    protected $keyType = 'string';

    public $incrementing = false;

    public const CREATED_AT = 'created_at';

    public const UPDATED_AT = null;

    public function match(): BelongsTo
    {
        return $this->belongsTo(ItemMatch::class);
    }

    public function sender(): BelongsTo
    {
        return $this->belongsTo(User::class, 'sender_id');
    }
}
