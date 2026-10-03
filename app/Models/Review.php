<?php

namespace App\Models;

use App\Services\Notifier;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Review extends Model
{
    protected $fillable = [
        'salon_id',
        'specialist_id',
        'booking_id',
        'customer_name',
        'rating',
        'comment',
        'is_visible',
    ];

    protected function casts(): array
    {
        return [
            'rating' => 'integer',
            'is_visible' => 'boolean',
        ];
    }

    protected static function booted(): void
    {
        $refresh = function (Review $review): void {
            $review->salon?->refreshRating();

            if ($review->wasChanged('salon_id')) {
                Salon::query()->find($review->getOriginal('salon_id'))?->refreshRating();
            }
        };

        static::saved($refresh);
        static::created(fn (Review $review) => app(Notifier::class)->reviewCreated($review));
        static::deleted(fn (Review $review) => $review->salon?->refreshRating());
    }

    public function salon(): BelongsTo
    {
        return $this->belongsTo(Salon::class);
    }

    public function specialist(): BelongsTo
    {
        return $this->belongsTo(Specialist::class);
    }

    public function booking(): BelongsTo
    {
        return $this->belongsTo(Booking::class);
    }
}
