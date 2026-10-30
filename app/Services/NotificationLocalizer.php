<?php

namespace App\Services;

use App\Models\AppNotification;
use App\Models\Booking;
use App\Models\SalonSubscription;

class NotificationLocalizer
{
    /**
     * @return array{title_en: ?string, body_en: ?string}
     */
    public function english(AppNotification $item): array
    {
        if (filled($item->title_en) && filled($item->body_en)) {
            return [
                'title_en' => $item->title_en,
                'body_en' => $item->body_en,
            ];
        }

        $fromBooking = $this->fromBooking($item);
        if ($fromBooking !== null) {
            return [
                'title_en' => $item->title_en ?: $fromBooking['title_en'],
                'body_en' => $item->body_en ?: $fromBooking['body_en'],
            ];
        }

        $static = $this->staticCopy($item);

        return [
            'title_en' => $item->title_en ?: $static['title_en'],
            'body_en' => $item->body_en ?: $static['body_en'],
        ];
    }

    /**
     * @return array{title_en: string, body_en: string}|null
     */
    private function fromBooking(AppNotification $item): ?array
    {
        $bookingId = $item->data['booking_id'] ?? null;
        if (! $bookingId) {
            return null;
        }

        $booking = Booking::query()
            ->with(['service', 'salon', 'user'])
            ->find($bookingId);

        if (! $booking) {
            return null;
        }

        $service = $this->serviceName($booking);
        $when = $this->when($booking);
        $salon = $this->salonName($booking);
        $customer = $this->customerName($booking);
        $pay = $booking->paymentLabel(true);
        $money = $this->money($booking->total);
        $audience = $item->data['audience'] ?? null;

        return match ($item->type) {
            'booking_created' => [
                'title_en' => 'Booking sent',
                'body_en' => "Your {$service} booking at {$salon} {$when} is awaiting salon confirmation. Payment: {$pay}.",
            ],
            'booking_new' => [
                'title_en' => 'New booking from '.$customer,
                'body_en' => "{$service} {$when} — total {$money} ({$pay}).",
            ],
            'booking_confirmed' => $audience === 'salon'
                ? [
                    'title_en' => 'Booking confirmed',
                    'body_en' => "{$customer}'s {$service} booking {$when} was confirmed.",
                ]
                : [
                    'title_en' => 'Booking confirmed',
                    'body_en' => "{$salon} confirmed your {$service} booking {$when}. See you soon!",
                ],
            'booking_cancelled' => $audience === 'salon'
                ? [
                    'title_en' => 'Booking cancelled',
                    'body_en' => $this->cancelBodySalon($item->title, $item->body, $customer, $service, $when),
                ]
                : [
                    'title_en' => 'Booking cancelled',
                    'body_en' => $this->cancelBodyCustomer($item->body, $salon, $service, $when),
                ],
            'booking_completed' => $audience === 'salon'
                ? [
                    'title_en' => 'Booking completed',
                    'body_en' => "{$customer}'s {$service} booking was completed.",
                ]
                : [
                    'title_en' => 'Visit completed',
                    'body_en' => $this->completedBodyCustomer($booking, $salon),
                ],
            'booking_pending' => $audience === 'salon'
                ? [
                    'title_en' => 'Booking pending',
                    'body_en' => "{$customer}'s {$service} booking {$when} awaits your confirmation.",
                ]
                : [
                    'title_en' => 'Awaiting confirmation',
                    'body_en' => "Your {$service} booking {$when} is pending again.",
                ],
            'booking_rescheduled' => $audience === 'salon'
                ? [
                    'title_en' => 'Booking rescheduled',
                    'body_en' => "{$customer}: {$service} booking is now {$when}.",
                ]
                : [
                    'title_en' => 'Booking rescheduled',
                    'body_en' => "Your {$service} booking is now {$when}.",
                ],
            'review_new' => [
                'title_en' => $this->reviewTitleEn($item->title),
                'body_en' => $this->reviewBodyEn($item->body, $booking),
            ],
            default => null,
        };
    }

    /**
     * @return array{title_en: ?string, body_en: ?string}
     */
    private function staticCopy(AppNotification $item): array
    {
        return match ($item->type) {
            'welcome' => [
                'title_en' => 'Welcome to Elmzin',
                'body_en' => str_contains((string) $item->body, 'صالون')
                    ? 'Your salon join request was received and is under review. We will notify you once it is verified.'
                    : 'Glad you joined! Discover top salons and book with ease.',
            ],
            'security' => [
                'title_en' => 'Password changed',
                'body_en' => 'Your account password was changed successfully. If this was not you, contact us immediately.',
            ],
            'salon_verified' => [
                'title_en' => 'Salon verified',
                'body_en' => $this->replaceSalonPhrase((string) $item->body, true),
            ],
            'salon_rejected' => [
                'title_en' => 'Verification not approved',
                'body_en' => $this->replaceSalonPhrase((string) $item->body, false),
            ],
            'salon_pending' => [
                'title_en' => 'Salon under review',
                'body_en' => $this->pendingSalonBody((string) $item->body),
            ],
            'subscription' => [
                'title_en' => 'Subscription activated',
                'body_en' => $this->subscriptionBodyEn($item),
            ],
            'wallet' => [
                'title_en' => $this->walletTitleEn((string) $item->title),
                'body_en' => $this->moneyBodyEn((string) $item->body),
            ],
            'loyalty' => [
                'title_en' => $this->loyaltyTitleEn((string) $item->title),
                'body_en' => $this->loyaltyBodyEn((string) $item->body),
            ],
            default => [
                'title_en' => $this->titleFallback((string) $item->title),
                'body_en' => $this->moneyBodyEn((string) $item->body),
            ],
        };
    }

    private function serviceName(Booking $booking): string
    {
        $service = $booking->service;
        if (! $service) {
            return 'the service';
        }

        return filled($service->name_en) ? $service->name_en : $service->name;
    }

    private function salonName(Booking $booking): string
    {
        $salon = $booking->salon;
        if (! $salon) {
            return 'the salon';
        }

        return filled($salon->name_en) ? $salon->name_en : $salon->name;
    }

    private function customerName(Booking $booking): string
    {
        if (filled($booking->customer_name)) {
            return $booking->customer_name;
        }

        $user = $booking->user;
        if ($user) {
            return filled($user->name_en) ? $user->name_en : $user->name;
        }

        return 'Customer';
    }

    private function when(Booking $booking): string
    {
        return trim('on '.$booking->booked_on?->format('Y-m-d').' at '.$booking->booked_time);
    }

    private function money(mixed $value): string
    {
        $number = (float) $value;
        $text = floor($number) == $number ? number_format($number) : number_format($number, 2);

        return $text.' EGP';
    }

    private function completedBodyCustomer(Booking $booking, string $salon): string
    {
        $points = (int) $booking->points_awarded;
        $extra = $points > 0 ? " You earned {$points} points." : '.';

        return "Thanks for visiting {$salon}{$extra} Rate your experience now.";
    }

    private function cancelBodyCustomer(string $body, string $salon, string $service, string $when): string
    {
        $reason = '';
        if (preg_match('/سبب الإلغاء\s*:?\s*(.+)$/u', $body, $match)) {
            $reason = ' Cancellation reason: '.trim($match[1]);
        }

        if (str_contains($body, 'ألغى '.$salon) || str_contains($body, "ألغى {$salon}")) {
            return "{$salon} cancelled your {$service} booking {$when}.{$reason}";
        }

        return "Cancelled your {$service} booking {$when}.{$reason}";
    }

    private function cancelBodySalon(string $title, string $body, string $customer, string $service, string $when): string
    {
        if (str_contains($body, 'ألغى '.$customer) || str_contains($body, "ألغى {$customer}")) {
            return "{$customer} cancelled the {$service} booking {$when}.";
        }

        return "Cancelled the {$service} booking {$when}.";
    }

    private function reviewTitleEn(string $title): string
    {
        if (preg_match('/(★+)/u', $title, $match)) {
            return 'New review '.$match[1];
        }

        return 'New review';
    }

    private function reviewBodyEn(string $body, Booking $booking): string
    {
        $name = $this->customerName($booking);
        if (preg_match('/(\d)\s*من\s*5/u', $body, $match)) {
            $comment = '';
            if (preg_match('/—\s*«(.+?)»/u', $body, $c)) {
                $comment = ' — «'.$c[1].'»';
            }

            return $name.' rated your salon '.$match[1].'/5'.$comment;
        }

        return $name.' rated your salon.';
    }

    private function subscriptionBodyEn(AppNotification $item): string
    {
        $subscriptionId = $item->data['subscription_id'] ?? null;
        if ($subscriptionId) {
            $subscription = SalonSubscription::query()->with('plan')->find($subscriptionId);
            if ($subscription) {
                $plan = filled($subscription->plan?->name_en)
                    ? $subscription->plan->name_en
                    : $subscription->plan_name;
                $until = $subscription->ends_at?->format('Y-m-d');
                $price = (float) $subscription->price <= 0
                    ? 'for free'
                    : 'for '.$this->money($subscription->price);

                return "Your {$plan} plan is active {$price} until {$until}.";
            }
        }

        $body = (string) $item->body;
        $body = str_replace(['اشتراكك في ', ' وساري حتى ', 'مجاناً', 'بقيمة ', ' ج.م'], ['Your ', ' until ', 'for free', 'for ', ' EGP'], $body);
        $body = preg_replace('/\s+/', ' ', trim($body)) ?? $body;

        return $body;
    }

    private function replaceSalonPhrase(string $body, bool $verified): string
    {
        if ($verified) {
            if (preg_match('/أصبح\s+(.+?)\s+موثقاً/u', $body, $match)) {
                return 'Congrats! '.trim($match[1]).' is now verified, visible to customers, and can take bookings.';
            }

            return 'Congrats! Your salon is now verified, visible to customers, and can take bookings.';
        }

        if (preg_match('/طلب\s+(.+?)\s+ولم/u', $body, $match)) {
            return 'Your request for '.trim($match[1]).' was reviewed and not approved. Contact support for details.';
        }

        return 'Your verification request was reviewed and not approved. Contact support for details.';
    }

    private function pendingSalonBody(string $body): string
    {
        if (preg_match('/أُعيد\s+(.+?)\s+إلى/u', $body, $match)) {
            return trim($match[1]).' was moved back to the verification queue.';
        }

        return 'Your salon was moved back to the verification queue.';
    }

    private function walletTitleEn(string $title): string
    {
        return match (true) {
            str_contains($title, 'شحن') => 'Wallet topped up',
            str_contains($title, 'استرداد') => 'Refund received',
            str_contains($title, 'مكافأة') => 'Reward received',
            str_contains($title, 'الدفع') => 'Wallet payment',
            str_contains($title, 'خصم') => 'Wallet deduction',
            default => 'Wallet update',
        };
    }

    private function loyaltyTitleEn(string $title): string
    {
        return match (true) {
            str_contains($title, 'ربحت') => 'Loyalty points earned',
            str_contains($title, 'أُضيفت') => 'Points added',
            str_contains($title, 'خُصمت') => 'Points deducted',
            str_contains($title, 'انتهت') => 'Points expired',
            default => 'Loyalty update',
        };
    }

    private function loyaltyBodyEn(string $body): string
    {
        if (preg_match('/(\d+)\s*نقطة/u', $body, $match)) {
            $points = $match[1];
            if (str_contains($body, 'أُضيفت') || str_contains($body, 'أضافت')) {
                return "{$points} points were added to your balance.";
            }
            if (str_contains($body, 'خصمت') || str_contains($body, 'خُصمت')) {
                return "{$points} points were deducted from your balance.";
            }
            if (str_contains($body, 'انتهت')) {
                return "{$points} points from your balance have expired.";
            }

            return "{$points} points updated on your balance.";
        }

        return $body;
    }

    private function moneyBodyEn(string $body): string
    {
        $out = str_replace(
            [
                'أُضيف',
                'أُعيد',
                'خُصم',
                'إلى محفظتك',
                'من محفظتك',
                'مكافأة',
                'الرصيد الحالي',
                ' ج.م',
                'الدفع عند الوصول',
                'فيزا',
            ],
            [
                'Added',
                'Refunded',
                'Deducted',
                'to your wallet',
                'from your wallet',
                'reward',
                'Current balance',
                ' EGP',
                'Pay on arrival',
                'Visa',
            ],
            $body,
        );

        return preg_replace('/\s+/', ' ', trim($out)) ?: $out;
    }

    private function titleFallback(string $title): ?string
    {
        $map = [
            'تم إرسال حجزك' => 'Booking sent',
            'تم تأكيد حجزك' => 'Booking confirmed',
            'تم تأكيد حجز' => 'Booking confirmed',
            'تم إلغاء حجزك' => 'Booking cancelled',
            'إلغاء حجز' => 'Booking cancelled',
            'اكتملت زيارتك' => 'Visit completed',
            'اكتمل حجز' => 'Booking completed',
            'حجزك بانتظار التأكيد' => 'Awaiting confirmation',
            'حجز بانتظار التأكيد' => 'Booking pending',
            'تم تغيير موعد الحجز' => 'Booking rescheduled',
            'تم تغيير موعد حجز' => 'Booking rescheduled',
            'تم تفعيل اشتراكك' => 'Subscription activated',
            'أهلاً بك في المزين' => 'Welcome to Elmzin',
            'تم تغيير كلمة المرور' => 'Password changed',
            'تم توثيق صالونك' => 'Salon verified',
            'لم يتم قبول طلب التوثيق' => 'Verification not approved',
            'صالونك قيد المراجعة' => 'Salon under review',
        ];

        if (isset($map[$title])) {
            return $map[$title];
        }

        if (str_starts_with($title, 'حجز جديد من ')) {
            return 'New booking from '.substr($title, strlen('حجز جديد من '));
        }

        return null;
    }
}
