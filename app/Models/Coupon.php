<?php

namespace App\Models;

use App\Enums\BookingStatus;
use App\Enums\CouponType;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Coupon extends Model
{
    protected $fillable = [
        'code',
        'title',
        'description',
        'type',
        'value',
        'min_amount',
        'max_discount',
        'usage_limit',
        'usage_limit_per_user',
        'starts_at',
        'ends_at',
        'is_active',
        'first_booking_only',
    ];

    protected function casts(): array
    {
        return [
            'type' => CouponType::class,
            'value' => 'decimal:2',
            'min_amount' => 'decimal:2',
            'max_discount' => 'decimal:2',
            'usage_limit' => 'integer',
            'usage_limit_per_user' => 'integer',
            'starts_at' => 'datetime',
            'ends_at' => 'datetime',
            'is_active' => 'boolean',
            'first_booking_only' => 'boolean',
        ];
    }

    protected static function booted(): void
    {
        static::saving(function (Coupon $coupon): void {
            $coupon->code = strtoupper(trim($coupon->code));
        });
    }

    public function salons(): BelongsToMany
    {
        return $this->belongsToMany(Salon::class);
    }

    public function redemptions(): HasMany
    {
        return $this->hasMany(CouponRedemption::class);
    }

    public function discountFor(float $amount): float
    {
        $discount = $this->type === CouponType::Percent
            ? round($amount * ((float) $this->value) / 100, 2)
            : round((float) $this->value, 2);

        if ($this->type === CouponType::Percent && $this->max_discount !== null) {
            $discount = min($discount, (float) $this->max_discount);
        }

        return round(min($discount, $amount), 2);
    }

    public function rejectionReason(?User $user, float $amount, ?int $salonId, ?int $ignoreBookingId = null): ?string
    {
        if (! $this->is_active) {
            return 'الكوبون غير مفعّل.';
        }

        if ($this->starts_at && $this->starts_at->isFuture()) {
            return 'الكوبون لم يبدأ بعد.';
        }

        if ($this->ends_at && $this->ends_at->isPast()) {
            return 'انتهت صلاحية الكوبون.';
        }

        if ($amount < (float) $this->min_amount) {
            return 'الحد الأدنى للطلب '.$this->min_amount.' ج.م.';
        }

        if ($this->salons()->exists() && ($salonId === null || ! $this->salons()->whereKey($salonId)->exists())) {
            return 'الكوبون لا يسري على هذا الصالون.';
        }

        $uses = $this->redemptions()
            ->when($ignoreBookingId, fn ($query) => $query->where('booking_id', '!=', $ignoreBookingId))
            ->count();

        if ($this->usage_limit !== null && $uses >= $this->usage_limit) {
            return 'استُنفد عدد استخدامات الكوبون.';
        }

        if ($this->usage_limit_per_user !== null) {
            if (! $user) {
                return 'هذا الكوبون محدود لكل مستخدم، اختر المستخدم أولاً.';
            }

            $userUses = $this->redemptions()
                ->where('user_id', $user->id)
                ->when($ignoreBookingId, fn ($query) => $query->where('booking_id', '!=', $ignoreBookingId))
                ->count();

            if ($userUses >= $this->usage_limit_per_user) {
                return 'استنفد المستخدم حد هذا الكوبون.';
            }
        }

        if ($this->first_booking_only) {
            if (! $user) {
                return 'كوبون أول حجز يتطلب مستخدماً مسجّلاً.';
            }

            $hasBooking = Booking::query()
                ->where('user_id', $user->id)
                ->where('status', '!=', BookingStatus::Cancelled)
                ->when($ignoreBookingId, fn ($query) => $query->whereKeyNot($ignoreBookingId))
                ->exists();

            if ($hasBooking) {
                return 'الكوبون متاح لأول حجز فقط.';
            }
        }

        return null;
    }
}
