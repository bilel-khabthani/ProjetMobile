<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Module Tinder Cards - trace des decisions de glissement.
 *
 * La decision metier reste stockee dans matches.decision.answer (LIKE = YES,
 * PASS = NO) pour rester compatible avec le parcours de verification. Cette
 * table conserve l'historique du deck : direction, confiance IA et metadonnees,
 * ce qui permet d'analyser les cartes passees sans relancer le matching.
 */
#[Fillable([
    'user_id',
    'item_match_id',
    'direction',
    'ai_confidence',
    'metadata',
])]
class SwipeDecision extends Model
{
    use HasUuids;

    protected $keyType = 'string';

    public $incrementing = false;

    public const DIRECTION_LIKE = 'LIKE';

    public const DIRECTION_PASS = 'PASS';

    protected function casts(): array
    {
        return [
            'ai_confidence' => 'integer',
            'metadata' => 'array',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function match(): BelongsTo
    {
        return $this->belongsTo(ItemMatch::class, 'item_match_id');
    }
}
