<?php

namespace App\Models;

use App\Enums\BookingStatus;
use Carbon\Carbon;
use Illuminate\Database\Eloquent\Model;

class BookingSetting extends Model
{
    protected $fillable = [
        'salon_cancel_hours_before',
        'salon_cancel_lock_enabled',
    ];

    protected function casts(): array
    {
        return [
            'salon_cancel_hours_before' => 'integer',
            'salon_cancel_lock_enabled' => 'boolean',
        ];
    }

    public static function current(): self
    {
        return static::query()->firstOrCreate([], [
            'salon_cancel_hours_before' => 2,
            'salon_cancel_lock_enabled' => true,
        ]);
    }

    public function hours(): int
    {
        return max(0, (int) $this->salon_cancel_hours_before);
    }

    public function lockMessage(): string
    {
        $hours = $this->hours();

        if ($hours <= 0) {
            return 'لا يمكن إلغاء الطلب في الوقت الحالي حسب إعدادات الإدارة.';
        }

        return "لا يمكن إلغاء الطلب قبل الموعد بأقل من {$hours} ساعة حسب إعدادات الإدارة.";
    }

    public function salonCancelBlocked(Booking $booking, ?Carbon $at = null): bool
    {
        if (! $this->salon_cancel_lock_enabled) {
            return false;
        }

        if ($booking->status !== BookingStatus::Confirmed) {
            return false;
        }

        $hours = $this->hours();
        if ($hours <= 0) {
            return true;
        }

        $moment = $this->bookingMoment($booking);
        $at ??= now();

        return $moment->greaterThan($at) && $moment->lessThanOrEqualTo($at->copy()->addHours($hours));
    }

    public function bookingMoment(Booking $booking): Carbon
    {
        $day = $booking->booked_on?->toDateString() ?? now()->toDateString();

        return Carbon::parse($day.' '.($booking->booked_time ?? '00:00'));
    }
}
