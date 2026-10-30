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

    public const UNITS_EN = [
        'day' => 'day',
        'month' => 'month',
        'year' => 'year',
    ];

    protected $fillable = [
        'name',
        'name_en',
        'tagline',
        'tagline_en',
        'badge',
        'badge_en',
        'price',
        'duration_value',
        'duration_unit',
        'features',
        'features_en',
        'terms',
        'terms_en',
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
            'features_en' => 'array',
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

    public function durationLabel(bool $english = false): string
    {
        $value = max(1, (int) $this->duration_value);

        if ($english) {
            $unit = match ($this->duration_unit) {
                'day' => $value === 1 ? 'day' : 'days',
                'month' => $value === 1 ? 'month' : 'months',
                default => $value === 1 ? 'year' : 'years',
            };

            return $value === 1 ? "1 $unit" : "$value $unit";
        }

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

    public function priceLabel(bool $english = false): string
    {
        if ($this->isFree()) {
            return $english ? 'Free' : 'مجاناً';
        }

        $price = (float) $this->price;
        $digits = floor($price) == $price ? number_format($price) : number_format($price, 2);

        return $english ? "EGP $digits" : $digits.' ج.م';
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
        $terms = array_values(array_filter(array_map('trim', preg_split('/\R/u', (string) $this->terms) ?: []), 'filled'));
        $termsEn = array_values(array_filter(array_map('trim', preg_split('/\R/u', (string) $this->terms_en) ?: []), 'filled'));

        return [
            'id' => $this->id,
            'name' => $this->name,
            'name_en' => $this->name_en,
            'tagline' => $this->tagline,
            'tagline_en' => $this->tagline_en,
            'badge' => $this->badge,
            'badge_en' => $this->badge_en,
            'price' => (float) $this->price,
            'price_label' => $this->priceLabel(),
            'price_label_en' => $this->priceLabel(true),
            'is_free' => $this->isFree(),
            'duration_value' => (int) $this->duration_value,
            'duration_unit' => $this->duration_unit,
            'duration_label' => $this->durationLabel(),
            'duration_label_en' => $this->durationLabel(true),
            'features' => array_values(array_filter((array) $this->features, 'filled')),
            'features_en' => array_values(array_filter((array) $this->features_en, 'filled')),
            'terms' => $terms,
            'terms_en' => $termsEn !== [] ? $termsEn : $terms,
            'max_services' => $this->max_services,
            'max_specialists' => $this->max_specialists,
            'is_featured' => $this->is_featured,
        ];
    }
}
