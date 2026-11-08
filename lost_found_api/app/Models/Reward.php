<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Reward extends Model
{
    use HasFactory;

    protected $fillable = [
        'title',
        'partner_name',
        'partner_type',
        'description',
        'points_cost',
        'discount_text',
        'icon_name',
        'color_hex',
        'terms',
        'is_active',
        'stock',
    ];

    protected function casts(): array
    {
        return [
            'points_cost' => 'integer',
            'is_active' => 'boolean',
            'stock' => 'integer',
        ];
    }

    public function userCoupons(): HasMany
    {
        return $this->hasMany(UserCoupon::class);
    }
}

