<?php

namespace App\Models;

use App\Services\Notifier;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SalonSubscription extends Model
{
    public const STATUSES = [
        'active' => 'فعّال',
        'expired' => 'منتهي',
        'cancelled' => 'ملغي',
    ];

    protected $fillable = [
        'salon_id',
        'subscription_plan_id',
        'plan_name',
        'price',
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
            'starts_at' => 'datetime',
            'ends_at' => 'datetime',
            'terms_accepted_at' => 'datetime',
        ];
    }

    protected static function booted(): void
    {
        static::saving(function (SalonSubscription $subscription): void {
            if (blank($subscription->plan_name) && $subscription->plan) {
                $subscription->plan_name = $subscription->plan->name;
            }
        });

        static::created(fn (SalonSubscription $subscription) => app(Notifier::class)->subscriptionStarted($subscription));
    }

    public function salon(): BelongsTo
    {
        return $this->belongsTo(Salon::class);
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
        return [
            'id' => $this->id,
            'plan_id' => $this->subscription_plan_id,
            'plan_name' => $this->plan_name,
            'price' => (float) $this->price,
            'is_free' => (float) $this->price <= 0,
            'starts_at' => $this->starts_at?->toDateString(),
            'ends_at' => $this->ends_at?->toDateString(),
            'status' => $this->state(),
            'status_label' => $this->stateLabel(),
            'days_left' => $this->daysLeft(),
            'max_services' => $this->plan?->max_services,
            'max_specialists' => $this->plan?->max_specialists,
        ];
    }
}
