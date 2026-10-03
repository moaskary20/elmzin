<?php

namespace App\Models;

use App\Enums\BookingStatus;
use App\Services\Notifier;
use App\Services\OfferService;
use Carbon\Carbon;
use Illuminate\Database\Eloquent\Casts\Attribute;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Booking extends Model
{
    public ?int $offerPreviousUserId = null;

    public ?string $actor = null;

    public bool $justCreated = false;

    /** @var list<string> */
    public array $justChanged = [];

    protected $fillable = [
        'salon_id',
        'specialist_id',
        'service_id',
        'user_id',
        'coupon_id',
        'customer_name',
        'customer_phone',
        'booked_on',
        'booked_time',
        'status',
        'payment_method',
        'card_last4',
        'notes',
        'subtotal',
        'discount_amount',
        'points_redeemed',
        'points_discount',
        'total',
        'points_awarded',
    ];

    public const PAYMENT_LABELS = [
        'cash' => 'الدفع عند الوصول',
        'card' => 'فيزا',
    ];

    public function paymentLabel(): string
    {
        $label = self::PAYMENT_LABELS[$this->payment_method] ?? self::PAYMENT_LABELS['cash'];

        return $this->payment_method === 'card' && $this->card_last4
            ? $label.' •••• '.$this->card_last4
            : $label;
    }

    protected function casts(): array
    {
        return [
            'booked_on' => 'date',
            'status' => BookingStatus::class,
            'subtotal' => 'decimal:2',
            'discount_amount' => 'decimal:2',
            'points_redeemed' => 'integer',
            'points_discount' => 'decimal:2',
            'total' => 'decimal:2',
            'points_awarded' => 'integer',
        ];
    }

    protected static function booted(): void
    {
        static::saving(function (Booking $booking): void {
            $original = $booking->getOriginal('user_id');
            $booking->offerPreviousUserId = $original ? (int) $original : null;
            app(OfferService::class)->price($booking);
        });

        static::saved(function (Booking $booking): void {
            $created = $booking->justCreated;
            $changed = $booking->justChanged;
            $booking->justCreated = false;
            $booking->justChanged = [];
            app(OfferService::class)->settle($booking);
            app(Notifier::class)->bookingSaved($booking, $changed, $created);
        });

        static::created(function (Booking $booking): void {
            $booking->justCreated = true;
        });

        static::updated(function (Booking $booking): void {
            $booking->justChanged = array_keys($booking->getChanges());
        });

        static::deleting(function (Booking $booking): void {
            app(OfferService::class)->release($booking);
        });
    }

    protected function bookedTime(): Attribute
    {
        return Attribute::make(
            get: fn (?string $value) => $value ? Carbon::parse($value)->format('H:i') : null,
            set: fn (?string $value) => $value ? Carbon::parse($value)->format('H:i:s') : null,
        );
    }

    public function salon(): BelongsTo
    {
        return $this->belongsTo(Salon::class);
    }

    public function specialist(): BelongsTo
    {
        return $this->belongsTo(Specialist::class);
    }

    public function service(): BelongsTo
    {
        return $this->belongsTo(Service::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function coupon(): BelongsTo
    {
        return $this->belongsTo(Coupon::class);
    }

    public function couponRedemption(): HasOne
    {
        return $this->hasOne(CouponRedemption::class);
    }

    public function reviews(): HasMany
    {
        return $this->hasMany(Review::class);
    }
}
