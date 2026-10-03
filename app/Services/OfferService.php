<?php

namespace App\Services;

use App\Enums\BookingStatus;
use App\Enums\LoyaltyTransactionType;
use App\Models\Booking;
use App\Models\Coupon;
use App\Models\CouponRedemption;
use App\Models\LoyaltySetting;
use App\Models\LoyaltyTransaction;
use App\Models\Service;
use App\Models\User;
use Illuminate\Validation\ValidationException;

class OfferService
{
    /**
     * @return array{
     *     subtotal: float,
     *     coupon_discount: float,
     *     points_discount: float,
     *     total: float,
     *     coupon_error: ?string,
     *     points_error: ?string,
     *     earn_points: int
     * }
     */
    public function quote(Booking $booking): array
    {
        $this->expireDue();

        $subtotal = round((float) (Service::query()->whereKey($booking->service_id)->value('price') ?? 0), 2);
        $cancelled = $booking->status === BookingStatus::Cancelled;

        if ($cancelled) {
            return $this->emptyQuote($subtotal);
        }

        $settings = LoyaltySetting::current();
        $user = $booking->user_id ? User::query()->find($booking->user_id) : null;
        $bookingId = $booking->exists ? (int) $booking->getKey() : null;
        $points = max(0, (int) $booking->points_redeemed);

        $couponError = null;
        $couponDiscount = 0.0;

        if ($booking->coupon_id) {
            $coupon = Coupon::query()->find($booking->coupon_id);

            if (! $coupon) {
                $couponError = 'الكوبون غير موجود.';
            } else {
                $couponError = $coupon->rejectionReason(
                    $user,
                    $subtotal,
                    $booking->salon_id ? (int) $booking->salon_id : null,
                    $bookingId,
                );

                if (! $couponError) {
                    $couponDiscount = $coupon->discountFor($subtotal);
                }
            }
        }

        $payable = max(0, round($subtotal - $couponDiscount, 2));
        $pointsError = null;
        $pointsDiscount = 0.0;

        if ($points > 0) {
            if (! $user) {
                $pointsError = 'اختر المستخدم قبل استبدال النقاط.';
            } elseif (! $settings->is_active) {
                $pointsError = 'برنامج نقاط الولاء متوقف.';
            } elseif ($settings->redeem_points < 1) {
                $pointsError = 'إعدادات الاستبدال غير مكتملة.';
            } elseif ($points < $settings->min_redeem_points) {
                $pointsError = 'الحد الأدنى للاستبدال هو '.$settings->min_redeem_points.' نقطة.';
            } elseif ($points % $settings->redeem_points !== 0) {
                $pointsError = 'يجب أن تكون النقاط من مضاعفات '.$settings->redeem_points.'.';
            } else {
                $available = $this->availablePoints($user, $bookingId);

                if ($points > $available) {
                    $pointsError = 'الرصيد المتاح '.$available.' نقطة.';
                } else {
                    $pointsDiscount = round(($points / $settings->redeem_points) * (float) $settings->redeem_value, 2);

                    if ($pointsDiscount > $payable) {
                        $pointsError = 'خصم النقاط أكبر من المبلغ المتبقي بعد الكوبون.';
                        $pointsDiscount = 0;
                    }
                }
            }
        }

        $total = max(0, round($payable - $pointsDiscount, 2));

        return [
            'subtotal' => $subtotal,
            'coupon_discount' => $couponDiscount,
            'points_discount' => $pointsDiscount,
            'total' => $total,
            'coupon_error' => $couponError,
            'points_error' => $pointsError,
            'earn_points' => $this->pointsEarned($settings, $user, $total),
        ];
    }

    public function price(Booking $booking): void
    {
        $booking->points_redeemed = max(0, (int) $booking->points_redeemed);
        $quote = $this->quote($booking);

        if ($booking->status !== BookingStatus::Cancelled) {
            if ($quote['coupon_error']) {
                throw ValidationException::withMessages([
                    'coupon_id' => $quote['coupon_error'],
                ]);
            }

            if ($quote['points_error']) {
                throw ValidationException::withMessages([
                    'points_redeemed' => $quote['points_error'],
                ]);
            }
        } else {
            $booking->points_redeemed = 0;
        }

        $booking->subtotal = $quote['subtotal'];
        $booking->discount_amount = $quote['coupon_discount'];
        $booking->points_discount = $quote['points_discount'];
        $booking->total = $quote['total'];
    }

    public function settle(Booking $booking): void
    {
        CouponRedemption::query()->where('booking_id', $booking->id)->delete();

        if (
            $booking->status !== BookingStatus::Cancelled
            && $booking->coupon_id
            && (float) $booking->discount_amount > 0
        ) {
            CouponRedemption::query()->create([
                'coupon_id' => $booking->coupon_id,
                'user_id' => $booking->user_id,
                'booking_id' => $booking->id,
                'discount_amount' => $booking->discount_amount,
            ]);
        }

        $userIds = collect([
            $booking->offerPreviousUserId,
            $booking->user_id,
        ])->filter()->map(fn ($id) => (int) $id)->unique();

        $this->syncRedeem($booking);
        $earn = $this->syncEarn($booking);

        if ((int) $booking->points_awarded !== $earn) {
            $booking->forceFill(['points_awarded' => $earn])->saveQuietly();
        }

        foreach ($userIds as $userId) {
            $user = User::query()->find($userId);

            if ($user) {
                $this->recalculate($user);
            }
        }
    }

    public function release(Booking $booking): void
    {
        $userIds = LoyaltyTransaction::query()
            ->where('booking_id', $booking->id)
            ->pluck('user_id');

        LoyaltyTransaction::query()
            ->where('booking_id', $booking->id)
            ->where('type', LoyaltyTransactionType::Redeem)
            ->delete();

        LoyaltyTransaction::query()
            ->where('booking_id', $booking->id)
            ->where('type', LoyaltyTransactionType::Earn)
            ->whereNull('processed_at')
            ->delete();

        LoyaltyTransaction::query()
            ->where('booking_id', $booking->id)
            ->update(['booking_id' => null]);

        foreach ($userIds->unique() as $userId) {
            $user = User::query()->find($userId);

            if ($user) {
                $this->recalculate($user);
            }
        }
    }

    public function adjust(User $user, int $points, string $note): LoyaltyTransaction
    {
        $this->expireDue();
        $user->refresh();

        if ($points === 0) {
            throw ValidationException::withMessages([
                'points' => 'أدخل عدداً غير صفر.',
            ]);
        }

        if ($user->loyalty_points + $points < 0) {
            throw ValidationException::withMessages([
                'points' => 'لا يمكن أن يصبح الرصيد سالباً. الرصيد الحالي '.$user->loyalty_points.'.',
            ]);
        }

        $transaction = $user->loyaltyTransactions()->create([
            'type' => LoyaltyTransactionType::Adjust,
            'points' => $points,
            'balance_after' => 0,
            'note' => $note,
        ]);

        $this->recalculate($user);

        return $transaction->refresh();
    }

    public function availablePoints(User $user, ?int $bookingId): int
    {
        $balance = (int) $user->loyalty_points;

        if (! $bookingId) {
            return max(0, $balance);
        }

        $held = (int) LoyaltyTransaction::query()
            ->where('booking_id', $bookingId)
            ->where('type', LoyaltyTransactionType::Redeem)
            ->sum('points');

        return max(0, $balance - $held);
    }

    public function recalculate(User $user): void
    {
        $balance = 0;

        foreach ($user->loyaltyTransactions()->orderBy('id')->get() as $transaction) {
            $balance += $transaction->points;

            if ((int) $transaction->balance_after !== $balance) {
                $transaction->forceFill(['balance_after' => $balance])->saveQuietly();
            }
        }

        if ((int) $user->loyalty_points !== $balance) {
            $user->forceFill(['loyalty_points' => $balance])->saveQuietly();
        }
    }

    public function expireDue(): void
    {
        $earns = LoyaltyTransaction::query()
            ->where('type', LoyaltyTransactionType::Earn)
            ->whereNotNull('expires_at')
            ->where('expires_at', '<=', now())
            ->whereNull('processed_at')
            ->orderBy('id')
            ->get();

        $userIds = [];

        foreach ($earns as $earn) {
            $user = User::query()->find($earn->user_id);

            if (! $user) {
                $earn->forceFill(['processed_at' => now()])->saveQuietly();

                continue;
            }

            $deduct = min($earn->points, max(0, (int) $user->loyalty_points));

            if ($deduct > 0) {
                LoyaltyTransaction::query()->create([
                    'user_id' => $user->id,
                    'type' => LoyaltyTransactionType::Expire,
                    'points' => -$deduct,
                    'balance_after' => 0,
                    'note' => 'انتهت صلاحية نقاط مكتسبة في '.$earn->created_at?->format('Y-m-d'),
                ]);
            }

            $earn->forceFill(['processed_at' => now()])->saveQuietly();
            $userIds[] = $user->id;
        }

        foreach (array_unique($userIds) as $userId) {
            $user = User::query()->find($userId);

            if ($user) {
                $this->recalculate($user);
            }
        }
    }

    private function syncRedeem(Booking $booking): void
    {
        LoyaltyTransaction::query()
            ->where('booking_id', $booking->id)
            ->where('type', LoyaltyTransactionType::Redeem)
            ->delete();

        if ($booking->status === BookingStatus::Cancelled || ! $booking->user_id || (int) $booking->points_redeemed < 1) {
            return;
        }

        LoyaltyTransaction::query()->create([
            'user_id' => $booking->user_id,
            'booking_id' => $booking->id,
            'type' => LoyaltyTransactionType::Redeem,
            'points' => -1 * (int) $booking->points_redeemed,
            'balance_after' => 0,
            'note' => 'استبدال على حجز #'.$booking->id,
        ]);
    }

    private function syncEarn(Booking $booking): int
    {
        $settings = LoyaltySetting::current();
        $user = $booking->user_id ? User::query()->find($booking->user_id) : null;
        $earn = 0;

        if ($booking->status === BookingStatus::Completed && $user) {
            $earn = $this->pointsEarned($settings, $user, (float) $booking->total);
        }

        $existing = LoyaltyTransaction::query()
            ->where('booking_id', $booking->id)
            ->where('type', LoyaltyTransactionType::Earn)
            ->first();

        if ($earn < 1 || ! $user) {
            if ($existing && ! $existing->processed_at) {
                $existing->delete();
            }

            return $existing && $existing->processed_at ? (int) $existing->points : 0;
        }

        if ($existing) {
            if ($existing->processed_at) {
                return (int) $existing->points;
            }

            $existing->update([
                'user_id' => $user->id,
                'points' => $earn,
                'note' => 'اكتساب من حجز #'.$booking->id,
            ]);

            return $earn;
        }

        LoyaltyTransaction::query()->create([
            'user_id' => $user->id,
            'booking_id' => $booking->id,
            'type' => LoyaltyTransactionType::Earn,
            'points' => $earn,
            'balance_after' => 0,
            'note' => 'اكتساب من حجز #'.$booking->id,
            'expires_at' => $settings->points_expire_days
                ? now()->addDays((int) $settings->points_expire_days)
                : null,
        ]);

        return $earn;
    }

    private function pointsEarned(LoyaltySetting $settings, ?User $user, float $total): int
    {
        if (! $user || ! $settings->is_active || (float) $settings->earn_amount <= 0) {
            return 0;
        }

        return (int) floor($total / (float) $settings->earn_amount) * (int) $settings->earn_points;
    }

    /**
     * @return array{
     *     subtotal: float,
     *     coupon_discount: float,
     *     points_discount: float,
     *     total: float,
     *     coupon_error: null,
     *     points_error: null,
     *     earn_points: int
     * }
     */
    private function emptyQuote(float $subtotal): array
    {
        return [
            'subtotal' => $subtotal,
            'coupon_discount' => 0,
            'points_discount' => 0,
            'total' => $subtotal,
            'coupon_error' => null,
            'points_error' => null,
            'earn_points' => 0,
        ];
    }
}
