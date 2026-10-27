<?php

namespace App\Models;

use App\Enums\ShopOrderStatus;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class ShopOrder extends Model
{
    protected $fillable = [
        'user_id',
        'customer_name',
        'customer_phone',
        'customer_address',
        'status',
        'payment_method',
        'card_last4',
        'total',
        'notes',
    ];

    protected function casts(): array
    {
        return [
            'status' => ShopOrderStatus::class,
            'total' => 'decimal:2',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function items(): HasMany
    {
        return $this->hasMany(ShopOrderItem::class);
    }

    public function refreshTotal(): void
    {
        $this->forceFill([
            'total' => round((float) $this->items()->sum('line_total'), 2),
        ])->saveQuietly();
    }
}
