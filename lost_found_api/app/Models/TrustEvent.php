<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['user_id', 'type', 'points', 'related_match_id', 'validated_by', 'reason'])]
class TrustEvent extends Model
{
    use HasUuids;

    protected $keyType = 'string';

    public $incrementing = false;

    public const UPDATED_AT = null;

    protected function casts(): array
    {
        return [
            'points' => 'integer',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /** Evenement systeme (regle automatique) ou arbitrage humain (CDC 7.1). */
    public function isSystemGenerated(): bool
    {
        return $this->validated_by === 'SYSTEME';
    }
}
