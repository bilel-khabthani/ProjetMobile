<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[Fillable([
    'lost_item_id', 'found_item_id', 'image_score', 'location_score',
    'time_score', 'text_score', 'global_score', 'status', 'decision',
    'verification_attempts', 'verified_at', 'owner_confirmed_at', 'finder_confirmed_at',
])]
class ItemMatch extends Model
{
    use HasUuids;

    protected $keyType = 'string';

    public $incrementing = false;

    /**
     * Le modele ne peut pas s'appeler "Match" : c'est un mot reserve en PHP 8,
     * donc le parseur le confond avec l'expression match(...). On garde donc
     * le nom de table "matches", conforme au schema du CDC.
     */
    protected $table = 'matches';

    public const STATUS_PENDING = 'PENDING';

    public const STATUS_VERIFIED = 'VERIFIED';

    public const STATUS_CONTACTED = 'CONTACTED';

    public const STATUS_RECOVERED = 'RECOVERED';

    public const STATUS_REJECTED = 'REJECTED';

    protected function casts(): array
    {
        return [
            'decision' => 'array',
            'image_score' => 'integer',
            'location_score' => 'integer',
            'time_score' => 'integer',
            'text_score' => 'integer',
            'global_score' => 'integer',
            'verification_attempts' => 'integer',
            'verified_at' => 'datetime',
            'owner_confirmed_at' => 'datetime',
            'finder_confirmed_at' => 'datetime',
        ];
    }

    public function lostItem(): BelongsTo
    {
        return $this->belongsTo(Item::class, 'lost_item_id');
    }

    public function foundItem(): BelongsTo
    {
        return $this->belongsTo(Item::class, 'found_item_id');
    }

    public function messages(): HasMany
    {
        return $this->hasMany(Message::class, 'match_id');
    }

    /** Evenements de score rattaches a cette correspondance (Module 4). */
    public function trustEvents(): HasMany
    {
        return $this->hasMany(TrustEvent::class, 'related_match_id');
    }

    /**
     * Module 5 - Double confirmation (CDC 6.4.4, exigence Must EF-09).
     * La restitution n'est validee que lorsque le proprietaire ET celui qui a
     * trouve l'objet ont confirme. Le systeme ne permet pas a l'un seul de valider.
     */
    public function isFullyConfirmed(): bool
    {
        return $this->owner_confirmed_at !== null && $this->finder_confirmed_at !== null;
    }
}
