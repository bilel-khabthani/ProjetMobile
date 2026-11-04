<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable([
    'user_id',
    'type', 'category', 'title', 'description', 'secret_detail',
    'latitude', 'longitude', 'place_label', 'occurred_at', 'status',
])]
class Item extends Model
{
    use HasUuids;

    protected $keyType = 'string';

    public $incrementing = false;

    public const TYPE_LOST = 'LOST';

    public const TYPE_FOUND = 'FOUND';

    protected function casts(): array
    {
        return [
            'latitude' => 'float',
            'longitude' => 'float',
            'occurred_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function lostMatches()
    {
        return $this->hasMany(ItemMatch::class, 'lost_item_id');
    }

    public function foundMatches()
    {
        return $this->hasMany(ItemMatch::class, 'found_item_id');
    }
}
