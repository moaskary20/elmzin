<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class LoyaltySetting extends Model
{
    protected $fillable = [
        'is_active',
        'earn_amount',
        'earn_points',
        'redeem_points',
        'redeem_value',
        'min_redeem_points',
        'points_expire_days',
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
            'earn_amount' => 'decimal:2',
            'earn_points' => 'integer',
            'redeem_points' => 'integer',
            'redeem_value' => 'decimal:2',
            'min_redeem_points' => 'integer',
            'points_expire_days' => 'integer',
        ];
    }

    public static function current(): self
    {
        return static::query()->firstOrCreate([], [
            'is_active' => true,
            'earn_amount' => 10,
            'earn_points' => 1,
            'redeem_points' => 100,
            'redeem_value' => 10,
            'min_redeem_points' => 100,
            'points_expire_days' => 365,
        ]);
    }
}
