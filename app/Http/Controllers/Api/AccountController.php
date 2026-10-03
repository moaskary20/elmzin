<?php

namespace App\Http\Controllers\Api;

use App\Enums\BookingStatus;
use App\Enums\LoyaltyTransactionType;
use App\Http\Controllers\Controller;
use App\Models\Booking;
use App\Models\LoyaltySetting;
use App\Models\LoyaltyTransaction;
use App\Models\Review;
use App\Models\User;
use App\Models\WalletTransaction;
use App\Services\Notifier;
use App\Services\OfferService;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpFoundation\BinaryFileResponse;

class AccountController extends Controller
{
    public function show(Request $request): JsonResponse
    {
        return response()->json([
            'data' => $this->account($request)->toAccountArray($request->getSchemeAndHttpHost()),
        ]);
    }

    public function update(Request $request): JsonResponse
    {
        $user = $this->account($request);

        $data = $request->validate([
            'name' => ['sometimes', 'required', 'string', 'max:120'],
            'phone' => ['sometimes', 'required', 'string', 'max:30', Rule::unique('users', 'phone')->ignore($user->id)],
            'notifications' => ['sometimes', 'boolean'],
            'dark_mode' => ['sometimes', 'boolean'],
            'locale' => ['sometimes', Rule::in(['ar', 'en'])],
        ], [
            'phone.unique' => 'رقم الهاتف مستخدم بالفعل.',
        ]);

        if (array_key_exists('name', $data)) {
            $user->name = $data['name'];
        }
        if (array_key_exists('phone', $data)) {
            $user->phone = $data['phone'];
        }
        if ($request->exists('notifications')) {
            $user->notifications_enabled = $request->boolean('notifications');
        }
        if ($request->exists('dark_mode')) {
            $user->dark_mode = $request->boolean('dark_mode');
        }
        if (array_key_exists('locale', $data)) {
            $user->locale = $data['locale'];
        }

        $user->save();

        return response()->json([
            'data' => $user->toAccountArray($request->getSchemeAndHttpHost()),
        ]);
    }

    public function avatar(Request $request): JsonResponse
    {
        $user = $this->account($request);

        $request->validate([
            'avatar' => ['required', 'image', 'max:4096'],
        ]);

        if ($user->avatar) {
            Storage::disk('public')->delete($user->avatar);
        }

        $user->avatar = $request->file('avatar')->store('avatars', 'public');
        $user->save();

        return response()->json([
            'data' => $user->toAccountArray($request->getSchemeAndHttpHost()),
        ]);
    }

    public function wallet(Request $request): JsonResponse
    {
        $user = $this->account($request);

        $transactions = $user->walletTransactions()
            ->latest('id')
            ->limit(100)
            ->get()
            ->map(fn (WalletTransaction $item) => [
                'id' => $item->id,
                'type' => $item->type->value,
                'label' => $item->type->getLabel(),
                'amount' => (float) $item->amount,
                'balance_after' => (float) $item->balance_after,
                'note' => $item->note,
                'booking_id' => $item->booking_id,
                'created_at' => $item->created_at?->toIso8601String(),
            ]);

        $credits = (float) $user->walletTransactions()->where('amount', '>', 0)->sum('amount');
        $debits = (float) $user->walletTransactions()->where('amount', '<', 0)->sum('amount');

        return response()->json([
            'data' => [
                'balance' => (float) $user->wallet_balance,
                'currency' => 'ج.م',
                'loyalty_points' => (int) $user->loyalty_points,
                'total_in' => round($credits, 2),
                'total_out' => round(abs($debits), 2),
                'transactions' => $transactions,
            ],
        ]);
    }

    public function loyalty(Request $request): JsonResponse
    {
        $user = $this->account($request);
        $offers = app(OfferService::class);
        $offers->expireDue();
        $user->refresh();

        $settings = LoyaltySetting::current();
        $balance = max(0, (int) $user->loyalty_points);
        $groups = $settings->redeem_points > 0 ? intdiv($balance, (int) $settings->redeem_points) : 0;
        $redeemable = $balance >= $settings->min_redeem_points ? $groups * (int) $settings->redeem_points : 0;
        $target = max((int) $settings->min_redeem_points, ($groups + 1) * (int) $settings->redeem_points);

        $transactions = $user->loyaltyTransactions();
        $sum = fn (LoyaltyTransactionType $type): int => (int) (clone $transactions)->where('type', $type)->sum('points');

        $expiring = (clone $transactions)
            ->where('type', LoyaltyTransactionType::Earn)
            ->whereNull('processed_at')
            ->whereNotNull('expires_at')
            ->where('expires_at', '<=', now()->addDays(30))
            ->orderBy('expires_at');

        return response()->json([
            'data' => [
                'points' => $balance,
                'is_active' => (bool) $settings->is_active,
                'redeemable_points' => $redeemable,
                'redeemable_value' => $settings->redeem_points > 0
                    ? round(($redeemable / $settings->redeem_points) * (float) $settings->redeem_value, 2)
                    : 0,
                'next_reward' => [
                    'target' => $target,
                    'remaining' => max(0, $target - $balance),
                    'value' => $settings->redeem_points > 0
                        ? round(($target / $settings->redeem_points) * (float) $settings->redeem_value, 2)
                        : 0,
                ],
                'rules' => [
                    'earn_amount' => (float) $settings->earn_amount,
                    'earn_points' => (int) $settings->earn_points,
                    'redeem_points' => (int) $settings->redeem_points,
                    'redeem_value' => (float) $settings->redeem_value,
                    'min_redeem_points' => (int) $settings->min_redeem_points,
                    'expire_days' => $settings->points_expire_days ? (int) $settings->points_expire_days : null,
                ],
                'totals' => [
                    'earned' => $sum(LoyaltyTransactionType::Earn) + max(0, (int) (clone $transactions)->where('type', LoyaltyTransactionType::Adjust)->where('points', '>', 0)->sum('points')),
                    'redeemed' => abs($sum(LoyaltyTransactionType::Redeem)),
                    'expired' => abs($sum(LoyaltyTransactionType::Expire)),
                ],
                'expiring' => [
                    'points' => (int) (clone $expiring)->sum('points'),
                    'date' => (clone $expiring)->value('expires_at') ? Carbon::parse((clone $expiring)->value('expires_at'))->toDateString() : null,
                ],
                'currency' => 'ج.م',
                'transactions' => (clone $transactions)
                    ->with('booking.salon:id,name')
                    ->latest('id')
                    ->limit(100)
                    ->get()
                    ->map(fn (LoyaltyTransaction $item): array => [
                        'id' => $item->id,
                        'type' => $item->type->value,
                        'label' => $item->type->getLabel(),
                        'points' => (int) $item->points,
                        'balance_after' => (int) $item->balance_after,
                        'note' => $item->note,
                        'salon' => $item->booking?->salon?->name,
                        'booking_id' => $item->booking_id,
                        'expires_at' => $item->type === LoyaltyTransactionType::Earn && ! $item->processed_at
                            ? $item->expires_at?->toDateString()
                            : null,
                        'created_at' => $item->created_at?->toIso8601String(),
                    ])
                    ->values(),
            ],
        ]);
    }

    public function salonImage(Request $request): JsonResponse
    {
        $user = $this->account($request);
        $salon = $user->salon;

        abort_if($salon === null, response()->json([
            'message' => 'هذا الحساب ليس له صالون.',
        ], 403));

        $request->validate([
            'image' => ['required', 'image', 'max:6144'],
        ], [
            'image.required' => 'اختر صورة الصالون.',
            'image.image' => 'الملف يجب أن يكون صورة.',
            'image.max' => 'حجم الصورة كبير، الحد ٦ ميجابايت.',
        ]);

        if ($salon->image) {
            Storage::disk('public')->delete($salon->image);
        }

        $salon->image = $request->file('image')->store('salons', 'public');
        $salon->save();

        return response()->json([
            'data' => [
                'id' => $salon->id,
                'image_url' => $request->getSchemeAndHttpHost().'/api/salons/'.$salon->id.'/image',
            ],
        ]);
    }

    public function avatarFile(User $user): BinaryFileResponse
    {
        abort_unless($user->avatar && Storage::disk('public')->exists($user->avatar), 404);

        return response()->file(Storage::disk('public')->path($user->avatar));
    }

    public function bookings(Request $request): JsonResponse
    {
        $user = $this->account($request);
        $this->claimPhoneBookings($user);

        $rows = $user->bookings()
            ->with(['salon.category', 'service', 'specialist', 'reviews'])
            ->orderByDesc('booked_on')
            ->orderByDesc('booked_time')
            ->get()
            ->map(fn (Booking $booking): array => $this->presentBooking($booking, $request))
            ->values();

        return response()->json(['data' => $rows]);
    }

    public function cancelBooking(Request $request, Booking $booking): JsonResponse
    {
        $user = $this->account($request);
        $this->owned($user, $booking);

        if (! $this->canCancel($booking)) {
            throw ValidationException::withMessages([
                'status' => 'لا يمكن إلغاء هذا الموعد.',
            ]);
        }

        $booking->status = BookingStatus::Cancelled;
        $booking->actor = Notifier::ACTOR_CUSTOMER;
        $booking->save();
        $booking->load(['salon.category', 'service', 'specialist', 'reviews']);

        return response()->json([
            'data' => $this->presentBooking($booking, $request),
        ]);
    }

    public function reviewBooking(Request $request, Booking $booking): JsonResponse
    {
        $user = $this->account($request);
        $this->owned($user, $booking);

        if ($booking->status !== BookingStatus::Completed) {
            throw ValidationException::withMessages([
                'rating' => 'يمكن التقييم بعد اكتمال الموعد.',
            ]);
        }

        if ($booking->reviews()->exists()) {
            throw ValidationException::withMessages([
                'rating' => 'تم تقييم هذا الموعد.',
            ]);
        }

        $data = $request->validate([
            'rating' => ['required', 'integer', 'between:1,5'],
            'comment' => ['nullable', 'string', 'max:500'],
        ]);

        Review::query()->create([
            'salon_id' => $booking->salon_id,
            'specialist_id' => $booking->specialist_id,
            'booking_id' => $booking->id,
            'customer_name' => $user->name,
            'rating' => $data['rating'],
            'comment' => $data['comment'] ?? null,
            'is_visible' => true,
        ]);

        $booking->load(['salon.category', 'service', 'specialist', 'reviews']);

        return response()->json([
            'data' => $this->presentBooking($booking, $request),
        ]);
    }

    private function account(Request $request): User
    {
        $user = User::findByBearer($request->bearerToken());

        abort_if($user === null, response()->json([
            'message' => 'يلزم تسجيل الدخول.',
        ], 401));

        return $user;
    }

    private function claimPhoneBookings(User $user): void
    {
        if ($user->phone === null || $user->phone === '') {
            return;
        }

        Booking::query()
            ->whereNull('user_id')
            ->where('customer_phone', $user->phone)
            ->update(['user_id' => $user->id]);
    }

    private function owned(User $user, Booking $booking): void
    {
        abort_unless($booking->user_id === $user->id, response()->json([
            'message' => 'هذا الموعد غير مرتبط بحسابك.',
        ], 404));
    }

    private function canCancel(Booking $booking): bool
    {
        if (! in_array($booking->status, [BookingStatus::Pending, BookingStatus::Confirmed], true)) {
            return false;
        }

        return $this->moment($booking)->isFuture();
    }

    private function moment(Booking $booking): Carbon
    {
        $day = $booking->booked_on?->toDateString() ?? now()->toDateString();

        return Carbon::parse($day.' '.($booking->booked_time ?? '00:00'));
    }

    private function presentBooking(Booking $booking, Request $request): array
    {
        $booking->loadMissing(['salon.category', 'service', 'specialist', 'reviews']);
        $salon = $booking->salon;
        $image = null;

        if ($salon && $salon->image && Storage::disk('public')->exists($salon->image)) {
            $image = $request->getSchemeAndHttpHost().'/api/salons/'.$salon->id.'/image';
        }

        return [
            'id' => $booking->id,
            'status' => $booking->status->value,
            'booked_on' => $booking->booked_on?->toDateString(),
            'booked_time' => $booking->booked_time,
            'notes' => $booking->notes,
            'subtotal' => (float) $booking->subtotal,
            'discount_amount' => (float) $booking->discount_amount,
            'total' => (float) $booking->total,
            'payment_method' => $booking->payment_method,
            'payment_label' => $booking->paymentLabel(),
            'points_awarded' => (int) $booking->points_awarded,
            'can_cancel' => $this->canCancel($booking),
            'can_review' => $booking->status === BookingStatus::Completed && $booking->reviews->isEmpty(),
            'reviewed' => $booking->reviews->isNotEmpty(),
            'salon' => [
                'id' => $salon?->id ?? 0,
                'name' => $salon?->name ?? '',
                'city' => $salon?->city ?? '',
                'district' => $salon?->district ?? '',
                'category_slug' => $salon?->category?->slug ?? '',
                'image_url' => $image,
            ],
            'service' => [
                'name' => $booking->service?->name ?? '',
                'duration_minutes' => (int) ($booking->service?->duration_minutes ?? 0),
            ],
            'specialist' => [
                'name' => $booking->specialist?->name ?? '',
                'title' => $booking->specialist?->title ?? '',
            ],
        ];
    }
}
