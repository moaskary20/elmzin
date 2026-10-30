<?php

namespace App\Models;

use App\Enums\VerificationStatus;
use App\Services\Notifier;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Salon extends Model
{
    protected $fillable = [
        'category_id',
        'user_id',
        'name',
        'name_en',
        'image',
        'health_certificate',
        'phone',
        'national_id',
        'city',
        'city_en',
        'district',
        'district_en',
        'address',
        'address_en',
        'latitude',
        'longitude',
        'about',
        'about_en',
        'verification_status',
        'is_active',
        'is_featured',
        'offers_home_service',
        'rating_avg',
        'reviews_count',
    ];

    protected function casts(): array
    {
        return [
            'verification_status' => VerificationStatus::class,
            'is_active' => 'boolean',
            'is_featured' => 'boolean',
            'offers_home_service' => 'boolean',
            'latitude' => 'float',
            'longitude' => 'float',
            'rating_avg' => 'float',
            'reviews_count' => 'integer',
        ];
    }

    protected static function booted(): void
    {
        static::saved(function (Salon $salon): void {
            app(Notifier::class)->salonSaved($salon);

            if ($salon->category_id && ($salon->wasRecentlyCreated || $salon->wasChanged('category_id'))) {
                $salon->categories()->syncWithoutDetaching([$salon->category_id]);
            }
        });
    }

    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class);
    }

    public function categories(): BelongsToMany
    {
        return $this->belongsToMany(Category::class);
    }

    public function media(): HasMany
    {
        return $this->hasMany(SalonMedia::class)->orderBy('sort_order')->orderBy('id');
    }

    /** @return list<int> */
    public function categoryIds(): array
    {
        $ids = $this->relationLoaded('categories')
            ? $this->categories->pluck('id')->all()
            : $this->categories()->pluck('categories.id')->all();

        if ($this->category_id) {
            $ids[] = (int) $this->category_id;
        }

        return array_values(array_unique(array_map('intval', $ids)));
    }

    public function owner(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function subscriptions(): HasMany
    {
        return $this->hasMany(SalonSubscription::class);
    }

    public function currentSubscription(): HasOne
    {
        return $this->hasOne(SalonSubscription::class)->current()->latestOfMany('ends_at');
    }

    public function workingHours(): HasMany
    {
        return $this->hasMany(WorkingHour::class);
    }

    public function services(): HasMany
    {
        return $this->hasMany(Service::class);
    }

    public function specialists(): HasMany
    {
        return $this->hasMany(Specialist::class);
    }

    public function bookings(): HasMany
    {
        return $this->hasMany(Booking::class);
    }

    public function reviews(): HasMany
    {
        return $this->hasMany(Review::class);
    }

    public function refreshRating(): void
    {
        $visible = $this->reviews()->where('is_visible', true);

        $this->forceFill([
            'rating_avg' => round((float) ($visible->avg('rating') ?? 0), 1),
            'reviews_count' => $this->reviews()->where('is_visible', true)->count(),
        ])->saveQuietly();
    }
}
