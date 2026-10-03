<?php

namespace App\Services;

use App\Enums\BookingStatus;
use App\Enums\LoyaltyTransactionType;
use App\Enums\UserRole;
use App\Enums\VerificationStatus;
use App\Enums\WalletTransactionType;
use App\Models\AppNotification;
use App\Models\Booking;
use App\Models\LoyaltyTransaction;
use App\Models\Review;
use App\Models\Salon;
use App\Models\SalonSubscription;
use App\Models\User;
use App\Models\WalletTransaction;
use Throwable;

class Notifier
{
    public const ACTOR_CUSTOMER = 'customer';

    public const ACTOR_SALON = 'salon';

    public function send(?int $userId, string $type, string $title, string $body, array $data = []): void
    {
        if (! $userId) {
            return;
        }

        try {
            AppNotification::query()->create([
                'user_id' => $userId,
                'type' => $type,
                'title' => $title,
                'body' => $body,
                'data' => $data ?: null,
            ]);
        } catch (Throwable $e) {
            report($e);
        }
    }

    /**
     * @param  list<string>  $changed
     */
    public function bookingSaved(Booking $booking, array $changed, bool $created): void
    {
        if ($created) {
            $this->bookingCreated($booking);

            return;
        }

        if (in_array('status', $changed, true)) {
            $this->bookingStatusChanged($booking);

            return;
        }

        if (array_intersect(['booked_on', 'booked_time'], $changed) !== []) {
            $body = 'أصبح موعد حجز '.$this->serviceName($booking).' '.$this->when($booking).'.';
            $this->toCustomer($booking, 'booking_rescheduled', 'تم تغيير موعد الحجز', $body);
            $this->toSalon($booking, 'booking_rescheduled', 'تم تغيير موعد حجز', $this->customerName($booking).': '.$body);
        }
    }

    private function bookingCreated(Booking $booking): void
    {
        $service = $this->serviceName($booking);
        $when = $this->when($booking);
        $salonName = $booking->salon?->name ?? 'الصالون';

        $this->toCustomer(
            $booking,
            'booking_created',
            'تم إرسال حجزك',
            "حجز {$service} في {$salonName} {$when} بانتظار تأكيد الصالون. طريقة الدفع: {$booking->paymentLabel()}.",
        );

        $this->toSalon(
            $booking,
            'booking_new',
            'حجز جديد من '.$this->customerName($booking),
            "{$service} {$when} — الإجمالي ".$this->money($booking->total).' ('.$booking->paymentLabel().').',
        );
    }

    private function bookingStatusChanged(Booking $booking): void
    {
        $actor = $booking->actor;
        $service = $this->serviceName($booking);
        $when = $this->when($booking);
        $salonName = $booking->salon?->name ?? 'الصالون';
        $customer = $this->customerName($booking);

        switch ($booking->status) {
            case BookingStatus::Confirmed:
                $this->toCustomer($booking, 'booking_confirmed', 'تم تأكيد حجزك', "أكّد {$salonName} حجز {$service} {$when}. نراك قريباً!");
                if ($actor !== self::ACTOR_SALON) {
                    $this->toSalon($booking, 'booking_confirmed', 'تم تأكيد حجز', "تم تأكيد حجز {$customer} لخدمة {$service} {$when}.");
                }
                break;

            case BookingStatus::Cancelled:
                $reason = $this->cancelReason($booking);
                if ($actor !== self::ACTOR_CUSTOMER) {
                    $by = $actor === self::ACTOR_SALON ? "ألغى {$salonName}" : 'تم إلغاء';
                    $this->toCustomer($booking, 'booking_cancelled', 'تم إلغاء حجزك', "{$by} حجز {$service} {$when}.{$reason}");
                }
                if ($actor !== self::ACTOR_SALON) {
                    $by = $actor === self::ACTOR_CUSTOMER ? "ألغى {$customer}" : 'تم إلغاء';
                    $this->toSalon($booking, 'booking_cancelled', 'إلغاء حجز', "{$by} حجز {$service} {$when}.");
                }
                break;

            case BookingStatus::Completed:
                $points = (int) $booking->points_awarded;
                $extra = $points > 0 ? " وربحت {$points} نقطة." : '.';
                $this->toCustomer($booking, 'booking_completed', 'اكتملت زيارتك', "شكراً لزيارتك {$salonName}{$extra} قيّم تجربتك الآن.");
                $this->toSalon($booking, 'booking_completed', 'اكتمل حجز', "تم إكمال حجز {$customer} لخدمة {$service}.");
                break;

            case BookingStatus::Pending:
                $this->toCustomer($booking, 'booking_pending', 'حجزك بانتظار التأكيد', "أُعيد حجز {$service} {$when} إلى حالة الانتظار.");
                $this->toSalon($booking, 'booking_pending', 'حجز بانتظار التأكيد', "حجز {$customer} لخدمة {$service} {$when} بانتظار تأكيدك.");
                break;
        }
    }

    public function reviewCreated(Review $review): void
    {
        $salon = $review->salon;
        $stars = str_repeat('★', max(1, min(5, (int) $review->rating)));
        $comment = filled($review->comment) ? ' — «'.mb_strimwidth((string) $review->comment, 0, 80, '…').'»' : '';

        $this->send(
            $salon?->user_id,
            'review_new',
            'تقييم جديد '.$stars,
            ($review->customer_name ?: 'عميل').' قيّم صالونك بـ '.$review->rating.' من 5'.$comment,
            ['booking_id' => $review->booking_id, 'review_id' => $review->id],
        );
    }

    public function salonSaved(Salon $salon): void
    {
        if (! $salon->wasChanged('verification_status')) {
            return;
        }

        match ($salon->verification_status) {
            VerificationStatus::Verified => $this->send($salon->user_id, 'salon_verified', 'تم توثيق صالونك', "مبروك! أصبح {$salon->name} موثقاً وظاهراً للعملاء ويمكنه استقبال الحجوزات."),
            VerificationStatus::Rejected => $this->send($salon->user_id, 'salon_rejected', 'لم يتم قبول طلب التوثيق', "تمت مراجعة طلب {$salon->name} ولم يُقبل. تواصل مع الإدارة لمعرفة التفاصيل."),
            VerificationStatus::Pending => $this->send($salon->user_id, 'salon_pending', 'صالونك قيد المراجعة', "أُعيد {$salon->name} إلى قائمة انتظار التوثيق."),
            default => null,
        };
    }

    public function subscriptionStarted(SalonSubscription $subscription): void
    {
        $ownerId = $subscription->salon?->user_id;
        $until = $subscription->ends_at?->format('Y-m-d');
        $price = (float) $subscription->price <= 0 ? 'مجاناً' : 'بقيمة '.$this->money($subscription->price);

        $this->send(
            $ownerId,
            'subscription',
            'تم تفعيل اشتراكك',
            "اشتراكك في {$subscription->plan_name} {$price} وساري حتى {$until}.",
            ['subscription_id' => $subscription->id],
        );
    }

    public function userCreated(User $user): void
    {
        if ($user->role === UserRole::Salon) {
            $this->send($user->id, 'welcome', 'أهلاً بك في المزين', 'تم استلام طلب انضمام صالونك وهو الآن قيد المراجعة، وسنبلغك فور توثيقه.');

            return;
        }

        if ($user->role === UserRole::Customer) {
            $this->send($user->id, 'welcome', 'أهلاً بك في المزين', 'سعداء بانضمامك! اكتشف أفضل الصالونات واحجز موعدك بسهولة.');
        }
    }

    public function passwordChanged(User $user): void
    {
        $this->send($user->id, 'security', 'تم تغيير كلمة المرور', 'تم تغيير كلمة مرور حسابك بنجاح. إن لم تكن أنت، تواصل معنا فوراً.');
    }

    public function walletCreated(WalletTransaction $tx): void
    {
        $amount = $this->money(abs((float) $tx->amount));
        $balance = $this->money($tx->balance_after);

        [$title, $body] = match ($tx->type) {
            WalletTransactionType::Deposit => ['تم شحن محفظتك', "أُضيف {$amount} إلى محفظتك."],
            WalletTransactionType::Refund => ['تم استرداد مبلغ', "أُعيد {$amount} إلى محفظتك."],
            WalletTransactionType::Reward => ['حصلت على مكافأة', "أُضيف {$amount} مكافأة إلى محفظتك."],
            WalletTransactionType::Payment => ['تم الدفع من المحفظة', "خُصم {$amount} من محفظتك."],
            WalletTransactionType::Withdrawal => ['خصم من المحفظة', "خُصم {$amount} من محفظتك."],
        };

        $note = filled($tx->note) ? ' '.$tx->note : '';

        $this->send($tx->user_id, 'wallet', $title, "{$body} الرصيد الحالي {$balance}.{$note}", [
            'booking_id' => $tx->booking_id,
        ]);
    }

    public function loyaltyCreated(LoyaltyTransaction $tx): void
    {
        $points = abs((int) $tx->points);

        [$title, $body] = match ($tx->type) {
            LoyaltyTransactionType::Earn => ['ربحت نقاط ولاء', "أُضيفت {$points} نقطة إلى رصيدك."],
            LoyaltyTransactionType::Adjust => $tx->points >= 0
                ? ['أُضيفت نقاط إلى رصيدك', "أضافت الإدارة {$points} نقطة."]
                : ['خُصمت نقاط من رصيدك', "خصمت الإدارة {$points} نقطة."],
            LoyaltyTransactionType::Expire => ['انتهت صلاحية نقاط', "انتهت صلاحية {$points} نقطة من رصيدك."],
            default => [null, null],
        };

        if ($title === null) {
            return;
        }

        $note = filled($tx->note) && $tx->type === LoyaltyTransactionType::Adjust ? ' '.$tx->note : '';

        $this->send($tx->user_id, 'loyalty', $title, $body.$note, [
            'booking_id' => $tx->booking_id,
        ]);
    }

    private function toCustomer(Booking $booking, string $type, string $title, string $body): void
    {
        $this->send($booking->user_id, $type, $title, $body, [
            'booking_id' => $booking->id,
            'audience' => 'customer',
        ]);
    }

    private function toSalon(Booking $booking, string $type, string $title, string $body): void
    {
        $ownerId = $booking->salon?->user_id;

        if (! $ownerId || $ownerId === $booking->user_id) {
            return;
        }

        $this->send($ownerId, $type, $title, $body, [
            'booking_id' => $booking->id,
            'audience' => 'salon',
        ]);
    }

    private function serviceName(Booking $booking): string
    {
        return $booking->service?->name ?? 'الخدمة';
    }

    private function customerName(Booking $booking): string
    {
        return $booking->customer_name ?: ($booking->user?->name ?? 'عميل');
    }

    private function when(Booking $booking): string
    {
        $date = $booking->booked_on?->format('Y-m-d');

        return trim('يوم '.$date.' الساعة '.$booking->booked_time);
    }

    private function money(mixed $value): string
    {
        $number = (float) $value;
        $text = floor($number) == $number ? number_format($number) : number_format($number, 2);

        return $text.' ج.م';
    }

    private function cancelReason(Booking $booking): string
    {
        if (! filled($booking->notes)) {
            return '';
        }

        $lines = array_reverse(explode("\n", (string) $booking->notes));

        foreach ($lines as $line) {
            if (str_starts_with($line, 'سبب الإلغاء')) {
                return ' '.trim($line);
            }
        }

        return '';
    }
}
