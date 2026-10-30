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

    public function send(
        ?int $userId,
        string $type,
        string $title,
        string $body,
        array $data = [],
        ?string $titleEn = null,
        ?string $bodyEn = null,
    ): void {
        if (! $userId) {
            return;
        }

        try {
            AppNotification::query()->create([
                'user_id' => $userId,
                'type' => $type,
                'title' => $title,
                'title_en' => $titleEn,
                'body' => $body,
                'body_en' => $bodyEn,
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
            $booking->loadMissing(['service', 'salon', 'user']);
            $service = $this->serviceName($booking);
            $serviceEn = $this->serviceName($booking, true);
            $when = $this->when($booking);
            $whenEn = $this->when($booking, true);
            $customer = $this->customerName($booking);
            $customerEn = $this->customerName($booking, true);

            $this->toCustomer(
                $booking,
                'booking_rescheduled',
                'تم تغيير موعد الحجز',
                'أصبح موعد حجز '.$service.' '.$when.'.',
                'Booking rescheduled',
                'Your '.$serviceEn.' booking is now '.$whenEn.'.',
            );
            $this->toSalon(
                $booking,
                'booking_rescheduled',
                'تم تغيير موعد حجز',
                $customer.': أصبح موعد حجز '.$service.' '.$when.'.',
                'Booking rescheduled',
                $customerEn.': '.$serviceEn.' booking is now '.$whenEn.'.',
            );
        }
    }

    private function bookingCreated(Booking $booking): void
    {
        $booking->loadMissing(['service', 'salon', 'user']);
        $service = $this->serviceName($booking);
        $serviceEn = $this->serviceName($booking, true);
        $when = $this->when($booking);
        $whenEn = $this->when($booking, true);
        $salonName = $this->salonName($booking);
        $salonNameEn = $this->salonName($booking, true);
        $pay = $booking->paymentLabel();
        $payEn = $booking->paymentLabel(true);
        $customer = $this->customerName($booking);
        $customerEn = $this->customerName($booking, true);

        $this->toCustomer(
            $booking,
            'booking_created',
            'تم إرسال حجزك',
            "حجز {$service} في {$salonName} {$when} بانتظار تأكيد الصالون. طريقة الدفع: {$pay}.",
            'Booking sent',
            "Your {$serviceEn} booking at {$salonNameEn} {$whenEn} is awaiting salon confirmation. Payment: {$payEn}.",
        );

        $this->toSalon(
            $booking,
            'booking_new',
            'حجز جديد من '.$customer,
            "{$service} {$when} — الإجمالي ".$this->money($booking->total).' ('.$pay.').',
            'New booking from '.$customerEn,
            "{$serviceEn} {$whenEn} — total ".$this->money($booking->total, true).' ('.$payEn.').',
        );
    }

    private function bookingStatusChanged(Booking $booking): void
    {
        $booking->loadMissing(['service', 'salon', 'user']);
        $actor = $booking->actor;
        $service = $this->serviceName($booking);
        $serviceEn = $this->serviceName($booking, true);
        $when = $this->when($booking);
        $whenEn = $this->when($booking, true);
        $salonName = $this->salonName($booking);
        $salonNameEn = $this->salonName($booking, true);
        $customer = $this->customerName($booking);
        $customerEn = $this->customerName($booking, true);

        switch ($booking->status) {
            case BookingStatus::Confirmed:
                $this->toCustomer(
                    $booking,
                    'booking_confirmed',
                    'تم تأكيد حجزك',
                    "أكّد {$salonName} حجز {$service} {$when}. نراك قريباً!",
                    'Booking confirmed',
                    "{$salonNameEn} confirmed your {$serviceEn} booking {$whenEn}. See you soon!",
                );
                if ($actor !== self::ACTOR_SALON) {
                    $this->toSalon(
                        $booking,
                        'booking_confirmed',
                        'تم تأكيد حجز',
                        "تم تأكيد حجز {$customer} لخدمة {$service} {$when}.",
                        'Booking confirmed',
                        "{$customerEn}'s {$serviceEn} booking {$whenEn} was confirmed.",
                    );
                }
                break;

            case BookingStatus::Cancelled:
                $reason = $this->cancelReason($booking);
                $reasonEn = $this->cancelReason($booking, true);
                if ($actor !== self::ACTOR_CUSTOMER) {
                    $by = $actor === self::ACTOR_SALON ? "ألغى {$salonName}" : 'تم إلغاء';
                    $byEn = $actor === self::ACTOR_SALON ? "{$salonNameEn} cancelled" : 'Cancelled';
                    $this->toCustomer(
                        $booking,
                        'booking_cancelled',
                        'تم إلغاء حجزك',
                        "{$by} حجز {$service} {$when}.{$reason}",
                        'Booking cancelled',
                        "{$byEn} your {$serviceEn} booking {$whenEn}.{$reasonEn}",
                    );
                }
                if ($actor !== self::ACTOR_SALON) {
                    $by = $actor === self::ACTOR_CUSTOMER ? "ألغى {$customer}" : 'تم إلغاء';
                    $byEn = $actor === self::ACTOR_CUSTOMER ? "{$customerEn} cancelled" : 'Cancelled';
                    $this->toSalon(
                        $booking,
                        'booking_cancelled',
                        'إلغاء حجز',
                        "{$by} حجز {$service} {$when}.",
                        'Booking cancelled',
                        "{$byEn} the {$serviceEn} booking {$whenEn}.",
                    );
                }
                break;

            case BookingStatus::Completed:
                $points = (int) $booking->points_awarded;
                $extra = $points > 0 ? " وربحت {$points} نقطة." : '.';
                $extraEn = $points > 0 ? " You earned {$points} points." : '.';
                $this->toCustomer(
                    $booking,
                    'booking_completed',
                    'اكتملت زيارتك',
                    "شكراً لزيارتك {$salonName}{$extra} قيّم تجربتك الآن.",
                    'Visit completed',
                    "Thanks for visiting {$salonNameEn}{$extraEn} Rate your experience now.",
                );
                $this->toSalon(
                    $booking,
                    'booking_completed',
                    'اكتمل حجز',
                    "تم إكمال حجز {$customer} لخدمة {$service}.",
                    'Booking completed',
                    "{$customerEn}'s {$serviceEn} booking was completed.",
                );
                break;

            case BookingStatus::Pending:
                $this->toCustomer(
                    $booking,
                    'booking_pending',
                    'حجزك بانتظار التأكيد',
                    "أُعيد حجز {$service} {$when} إلى حالة الانتظار.",
                    'Awaiting confirmation',
                    "Your {$serviceEn} booking {$whenEn} is pending again.",
                );
                $this->toSalon(
                    $booking,
                    'booking_pending',
                    'حجز بانتظار التأكيد',
                    "حجز {$customer} لخدمة {$service} {$when} بانتظار تأكيدك.",
                    'Booking pending',
                    "{$customerEn}'s {$serviceEn} booking {$whenEn} awaits your confirmation.",
                );
                break;
        }
    }

    public function reviewCreated(Review $review): void
    {
        $salon = $review->salon;
        $stars = str_repeat('★', max(1, min(5, (int) $review->rating)));
        $comment = filled($review->comment) ? ' — «'.mb_strimwidth((string) $review->comment, 0, 80, '…').'»' : '';
        $name = $review->customer_name ?: 'عميل';
        $nameEn = $review->customer_name ?: 'A customer';

        $this->send(
            $salon?->user_id,
            'review_new',
            'تقييم جديد '.$stars,
            $name.' قيّم صالونك بـ '.$review->rating.' من 5'.$comment,
            ['booking_id' => $review->booking_id, 'review_id' => $review->id],
            'New review '.$stars,
            $nameEn.' rated your salon '.$review->rating.'/5'.$comment,
        );
    }

    public function salonSaved(Salon $salon): void
    {
        if (! $salon->wasChanged('verification_status')) {
            return;
        }

        $name = $salon->name;
        $nameEn = filled($salon->name_en) ? $salon->name_en : $salon->name;

        match ($salon->verification_status) {
            VerificationStatus::Verified => $this->send(
                $salon->user_id,
                'salon_verified',
                'تم توثيق صالونك',
                "مبروك! أصبح {$name} موثقاً وظاهراً للعملاء ويمكنه استقبال الحجوزات.",
                [],
                'Salon verified',
                "Congrats! {$nameEn} is now verified, visible to customers, and can take bookings.",
            ),
            VerificationStatus::Rejected => $this->send(
                $salon->user_id,
                'salon_rejected',
                'لم يتم قبول طلب التوثيق',
                "تمت مراجعة طلب {$name} ولم يُقبل. تواصل مع الإدارة لمعرفة التفاصيل.",
                [],
                'Verification not approved',
                "Your request for {$nameEn} was reviewed and not approved. Contact support for details.",
            ),
            VerificationStatus::Pending => $this->send(
                $salon->user_id,
                'salon_pending',
                'صالونك قيد المراجعة',
                "أُعيد {$name} إلى قائمة انتظار التوثيق.",
                [],
                'Salon under review',
                "{$nameEn} was moved back to the verification queue.",
            ),
            default => null,
        };
    }

    public function subscriptionStarted(SalonSubscription $subscription): void
    {
        $subscription->loadMissing(['salon', 'plan']);
        $ownerId = $subscription->salon?->user_id;
        $until = $subscription->ends_at?->format('Y-m-d');
        $plan = $subscription->plan_name;
        $planEn = filled($subscription->plan?->name_en) ? $subscription->plan->name_en : $plan;
        $price = (float) $subscription->price <= 0
            ? 'مجاناً'
            : 'بقيمة '.$this->money($subscription->price);
        $priceEn = (float) $subscription->price <= 0
            ? 'for free'
            : 'for '.$this->money($subscription->price, true);

        $this->send(
            $ownerId,
            'subscription',
            'تم تفعيل اشتراكك',
            "اشتراكك في {$plan} {$price} وساري حتى {$until}.",
            ['subscription_id' => $subscription->id],
            'Subscription activated',
            "Your {$planEn} plan is active {$priceEn} until {$until}.",
        );
    }

    public function userCreated(User $user): void
    {
        if ($user->role === UserRole::Salon) {
            $this->send(
                $user->id,
                'welcome',
                'أهلاً بك في المزين',
                'تم استلام طلب انضمام صالونك وهو الآن قيد المراجعة، وسنبلغك فور توثيقه.',
                [],
                'Welcome to Elmzin',
                'Your salon join request was received and is under review. We will notify you once it is verified.',
            );

            return;
        }

        if ($user->role === UserRole::Customer) {
            $this->send(
                $user->id,
                'welcome',
                'أهلاً بك في المزين',
                'سعداء بانضمامك! اكتشف أفضل الصالونات واحجز موعدك بسهولة.',
                [],
                'Welcome to Elmzin',
                'Glad you joined! Discover top salons and book with ease.',
            );
        }
    }

    public function passwordChanged(User $user): void
    {
        $this->send(
            $user->id,
            'security',
            'تم تغيير كلمة المرور',
            'تم تغيير كلمة مرور حسابك بنجاح. إن لم تكن أنت، تواصل معنا فوراً.',
            [],
            'Password changed',
            'Your account password was changed successfully. If this was not you, contact us immediately.',
        );
    }

    public function walletCreated(WalletTransaction $tx): void
    {
        $amount = $this->money(abs((float) $tx->amount));
        $amountEn = $this->money(abs((float) $tx->amount), true);
        $balance = $this->money($tx->balance_after);
        $balanceEn = $this->money($tx->balance_after, true);

        [$title, $body, $titleEn, $bodyEn] = match ($tx->type) {
            WalletTransactionType::Deposit => [
                'تم شحن محفظتك',
                "أُضيف {$amount} إلى محفظتك.",
                'Wallet topped up',
                "{$amountEn} was added to your wallet.",
            ],
            WalletTransactionType::Refund => [
                'تم استرداد مبلغ',
                "أُعيد {$amount} إلى محفظتك.",
                'Refund received',
                "{$amountEn} was refunded to your wallet.",
            ],
            WalletTransactionType::Reward => [
                'حصلت على مكافأة',
                "أُضيف {$amount} مكافأة إلى محفظتك.",
                'Reward received',
                "{$amountEn} reward was added to your wallet.",
            ],
            WalletTransactionType::Payment => [
                'تم الدفع من المحفظة',
                "خُصم {$amount} من محفظتك.",
                'Wallet payment',
                "{$amountEn} was deducted from your wallet.",
            ],
            WalletTransactionType::Withdrawal => [
                'خصم من المحفظة',
                "خُصم {$amount} من محفظتك.",
                'Wallet deduction',
                "{$amountEn} was deducted from your wallet.",
            ],
        };

        $note = filled($tx->note) ? ' '.$tx->note : '';

        $this->send(
            $tx->user_id,
            'wallet',
            $title,
            "{$body} الرصيد الحالي {$balance}.{$note}",
            ['booking_id' => $tx->booking_id],
            $titleEn,
            "{$bodyEn} Current balance {$balanceEn}.{$note}",
        );
    }

    public function loyaltyCreated(LoyaltyTransaction $tx): void
    {
        $points = abs((int) $tx->points);

        [$title, $body, $titleEn, $bodyEn] = match ($tx->type) {
            LoyaltyTransactionType::Earn => [
                'ربحت نقاط ولاء',
                "أُضيفت {$points} نقطة إلى رصيدك.",
                'Loyalty points earned',
                "{$points} points were added to your balance.",
            ],
            LoyaltyTransactionType::Adjust => $tx->points >= 0
                ? [
                    'أُضيفت نقاط إلى رصيدك',
                    "أضافت الإدارة {$points} نقطة.",
                    'Points added',
                    "Admin added {$points} points.",
                ]
                : [
                    'خُصمت نقاط من رصيدك',
                    "خصمت الإدارة {$points} نقطة.",
                    'Points deducted',
                    "Admin deducted {$points} points.",
                ],
            LoyaltyTransactionType::Expire => [
                'انتهت صلاحية نقاط',
                "انتهت صلاحية {$points} نقطة من رصيدك.",
                'Points expired',
                "{$points} points from your balance have expired.",
            ],
            default => [null, null, null, null],
        };

        if ($title === null) {
            return;
        }

        $note = filled($tx->note) && $tx->type === LoyaltyTransactionType::Adjust ? ' '.$tx->note : '';

        $this->send(
            $tx->user_id,
            'loyalty',
            $title,
            $body.$note,
            ['booking_id' => $tx->booking_id],
            $titleEn,
            $bodyEn.$note,
        );
    }

    private function toCustomer(
        Booking $booking,
        string $type,
        string $title,
        string $body,
        string $titleEn,
        string $bodyEn,
    ): void {
        $this->send($booking->user_id, $type, $title, $body, [
            'booking_id' => $booking->id,
            'audience' => 'customer',
        ], $titleEn, $bodyEn);
    }

    private function toSalon(
        Booking $booking,
        string $type,
        string $title,
        string $body,
        string $titleEn,
        string $bodyEn,
    ): void {
        $ownerId = $booking->salon?->user_id;

        if (! $ownerId || $ownerId === $booking->user_id) {
            return;
        }

        $this->send($ownerId, $type, $title, $body, [
            'booking_id' => $booking->id,
            'audience' => 'salon',
        ], $titleEn, $bodyEn);
    }

    private function serviceName(Booking $booking, bool $english = false): string
    {
        $service = $booking->service;
        if (! $service) {
            return $english ? 'the service' : 'الخدمة';
        }

        if ($english && filled($service->name_en)) {
            return $service->name_en;
        }

        return $service->name;
    }

    private function salonName(Booking $booking, bool $english = false): string
    {
        $salon = $booking->salon;
        if (! $salon) {
            return $english ? 'the salon' : 'الصالون';
        }

        if ($english && filled($salon->name_en)) {
            return $salon->name_en;
        }

        return $salon->name;
    }

    private function customerName(Booking $booking, bool $english = false): string
    {
        if (filled($booking->customer_name)) {
            return $booking->customer_name;
        }

        $user = $booking->user;
        if ($user) {
            if ($english && filled($user->name_en)) {
                return $user->name_en;
            }

            return $user->name;
        }

        return $english ? 'Customer' : 'عميل';
    }

    private function when(Booking $booking, bool $english = false): string
    {
        $date = $booking->booked_on?->format('Y-m-d');
        $time = $booking->booked_time;

        if ($english) {
            return trim('on '.$date.' at '.$time);
        }

        return trim('يوم '.$date.' الساعة '.$time);
    }

    private function money(mixed $value, bool $english = false): string
    {
        $number = (float) $value;
        $text = floor($number) == $number ? number_format($number) : number_format($number, 2);

        return $english ? $text.' EGP' : $text.' ج.م';
    }

    private function cancelReason(Booking $booking, bool $english = false): string
    {
        if (! filled($booking->notes)) {
            return '';
        }

        $lines = array_reverse(explode("\n", (string) $booking->notes));

        foreach ($lines as $line) {
            if (str_starts_with($line, 'سبب الإلغاء')) {
                $text = trim($line);
                if ($english) {
                    $text = str_replace('سبب الإلغاء', 'Cancellation reason', $text);
                }

                return ' '.$text;
            }
        }

        return '';
    }
}
