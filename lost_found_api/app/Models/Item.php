<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[Fillable([
    'user_id', 'category_id',
    'type', 'category', 'title', 'description', 'secret_detail',
    'latitude', 'longitude', 'place_label', 'occurred_at', 'status',
    'image_path', 'contact_phone',
])]
class Item extends Model
{
    use HasUuids;

    protected $keyType = 'string';

    public $incrementing = false;

    protected $appends = ['image_url'];

    protected $hidden = ['secret_detail'];

    public const TYPE_LOST = 'LOST';

    public const TYPE_FOUND = 'FOUND';

    public const STATUS_ACTIVE = 'ACTIVE';
    public const STATUS_RECOVERED = 'RECOVERED';
    public const STATUS_RESOLVED = 'RESOLVED';
    public const STATUS_CLOSED = 'CLOSED';

    public function getImageUrlAttribute(): ?string
    {
        if (!$this->image_path) {
            return null;
        }

        if (str_starts_with($this->image_path, 'http://') || str_starts_with($this->image_path, 'https://')) {
            return $this->image_path;
        }

        return url('storage/' . ltrim($this->image_path, '/'));
    }

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

    public function categoryRef(): BelongsTo
    {
        return $this->belongsTo(Category::class, 'category_id');
    }

    public function images(): HasMany
    {
        return $this->hasMany(ItemImage::class);
    }

    public function favorites(): HasMany
    {
        return $this->hasMany(ObjectFavorite::class);
    }

    public function reports(): HasMany
    {
        return $this->hasMany(ObjectReport::class);
    }

    public function events(): HasMany
    {
        return $this->hasMany(ObjectEvent::class);
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
