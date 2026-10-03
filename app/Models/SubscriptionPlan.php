<?php

namespace App\Models;

use Carbon\CarbonInterface;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class SubscriptionPlan extends Model
{
    public const UNITS = [
        'day' => 'يوم',
        'month' => 'شهر',
        'year' => 'سنة',
    ];

    protected $fillable = [
        'name',
        'tagline',
        'badge',
        'price',
        'duration_value',
        'duration_unit',
        'features',
        'terms',
        'max_services',
        'max_specialists',
        'is_featured',
        'is_active',
        'sort_order',
    ];

    protected function casts(): array
    {
        return [
            'price' => 'decimal:2',
            'duration_value' => 'integer',
            'features' => 'array',
            'max_services' => 'integer',
            'max_specialists' => 'integer',
            'is_featured' => 'boolean',
            'is_active' => 'boolean',
            'sort_order' => 'integer',
        ];
    }

    public function subscriptions(): HasMany
    {
        return $this->hasMany(SalonSubscription::class);
    }

    public function scopeAvailable(Builder $query): Builder
    {
        return $query->where('is_active', true)->orderBy('sort_order')->orderBy('id');
    }

    public function isFree(): bool
    {
        return (float) $this->price <= 0;
    }

    public function durationLabel(): string
    {
        $value = max(1, (int) $this->duration_value);

        return match ($this->duration_unit) {
            'day' => match (true) {
                $value === 1 => 'يوم واحد',
                $value === 2 => 'يومان',
                $value <= 10 => $value.' أيام',
                default => $value.' يوماً',
            },
            'month' => match (true) {
                $value === 1 => 'شهر واحد',
                $value === 2 => 'شهران',
                $value <= 10 => $value.' أشهر',
                default => $value.' شهراً',
            },
            default => match (true) {
                $value === 1 => 'سنة واحدة',
                $value === 2 => 'سنتان',
                $value <= 10 => $value.' سنوات',
                default => $value.' سنة',
            },
        };
    }

    public function priceLabel(): string
    {
        if ($this->isFree()) {
            return 'مجاناً';
        }

        $price = (float) $this->price;

        return (floor($price) == $price ? number_format($price) : number_format($price, 2)).' ج.م';
    }

    public function endsFrom(CarbonInterface $start): CarbonInterface
    {
        $value = max(1, (int) $this->duration_value);

        return match ($this->duration_unit) {
            'day' => $start->copy()->addDays($value),
            'month' => $start->copy()->addMonthsNoOverflow($value),
            default => $start->copy()->addYearsNoOverflow($value),
        };
    }

    public function toApiArray(): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'tagline' => $this->tagline,
            'badge' => $this->badge,
            'price' => (float) $this->price,
            'price_label' => $this->priceLabel(),
            'is_free' => $this->isFree(),
            'duration_value' => (int) $this->duration_value,
            'duration_unit' => $this->duration_unit,
            'duration_label' => $this->durationLabel(),
            'features' => array_values(array_filter((array) $this->features, 'filled')),
            'terms' => array_values(array_filter(array_map('trim', preg_split('/\R/u', (string) $this->terms) ?: []), 'filled')),
            'max_services' => $this->max_services,
            'max_specialists' => $this->max_specialists,
            'is_featured' => $this->is_featured,
        ];
    }
}
