<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SellerSubscription extends Model
{
    public const STATUSES = [
        'active' => 'فعّال',
        'expired' => 'منتهي',
        'cancelled' => 'ملغي',
    ];

    protected $fillable = [
        'user_id',
        'subscription_plan_id',
        'plan_name',
        'pricing_type',
        'price',
        'commission_percent',
        'starts_at',
        'ends_at',
        'status',
        'terms_accepted_at',
        'notes',
    ];

    protected function casts(): array
    {
        return [
            'price' => 'decimal:2',
            'commission_percent' => 'decimal:2',
            'starts_at' => 'datetime',
            'ends_at' => 'datetime',
            'terms_accepted_at' => 'datetime',
        ];
    }

    public function isPercentage(): bool
    {
        return ($this->pricing_type ?? 'fixed') === 'percentage';
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function plan(): BelongsTo
    {
        return $this->belongsTo(SubscriptionPlan::class, 'subscription_plan_id');
    }

    public function scopeCurrent(Builder $query): Builder
    {
        return $query->where('status', 'active')
            ->where('starts_at', '<=', now())
            ->where('ends_at', '>', now());
    }

    public function state(): string
    {
        if ($this->status === 'active' && $this->ends_at?->isPast()) {
            return 'expired';
        }

        return $this->status;
    }

    public function stateLabel(): string
    {
        return self::STATUSES[$this->state()] ?? $this->status;
    }

    public function daysLeft(): int
    {
        if ($this->state() !== 'active' || ! $this->ends_at) {
            return 0;
        }

        return (int) max(0, ceil(now()->diffInHours($this->ends_at, false) / 24));
    }

    public function toApiArray(): array
    {
        $isPercentage = $this->isPercentage();

        return [
            'id' => $this->id,
            'plan_id' => $this->subscription_plan_id,
            'plan_name' => $this->plan_name,
            'pricing_type' => $isPercentage ? 'percentage' : 'fixed',
            'price' => (float) $this->price,
            'commission_percent' => $isPercentage ? (float) ($this->commission_percent ?? 0) : null,
            'is_free' => ! $isPercentage && (float) $this->price <= 0,
            'is_percentage' => $isPercentage,
            'starts_at' => $this->starts_at?->toDateString(),
            'ends_at' => $this->ends_at?->toDateString(),
            'status' => $this->state(),
            'status_label' => $this->stateLabel(),
            'days_left' => $this->daysLeft(),
        ];
    }
}
