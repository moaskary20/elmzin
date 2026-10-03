<?php

namespace App\Http\Controllers\Api;

use App\Enums\BookingStatus;
use App\Enums\UserRole;
use App\Http\Controllers\Controller;
use App\Models\Booking;
use App\Models\Salon;
use App\Models\User;
use App\Services\Notifier;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\ValidationException;

class SalonBookingController extends Controller
{
    private const RELATIONS = ['service', 'specialist', 'user', 'coupon'];

    public function index(Request $request): JsonResponse
    {
        $salon = $this->salon($request);

        $bookings = $salon->bookings()
            ->with(self::RELATIONS)
            ->orderByDesc('booked_on')
            ->orderByDesc('booked_time')
            ->get();

        $visits = $this->visitCounts($salon);

        return response()->json([
            'salon' => [
                'id' => $salon->id,
                'name' => $salon->name,
                'verification_status' => $salon->verification_status?->value,
            ],
            'data' => $bookings
                ->map(fn (Booking $booking): array => $this->present($booking, $request, $visits))
                ->values(),
        ]);
    }

    public function confirm(Request $request, Booking $booking): JsonResponse
    {
        $salon = $this->salon($request);
        $this->owned($salon, $booking);

        if (! $this->canConfirm($booking)) {
            throw ValidationException::withMessages([
                'status' => 'لا يمكن تأكيد هذا الحجز.',
            ]);
        }

        $booking->status = BookingStatus::Confirmed;
        $booking->actor = Notifier::ACTOR_SALON;
        $booking->save();

        return $this->respond($salon, $booking, $request);
    }

    public function cancel(Request $request, Booking $booking): JsonResponse
    {
        $salon = $this->salon($request);
        $this->owned($salon, $booking);

        if (! $this->canCancel($booking)) {
            throw ValidationException::withMessages([
                'status' => 'لا يمكن إلغاء هذا الحجز.',
            ]);
        }

        $data = $request->validate([
            'reason' => ['nullable', 'string', 'max:300'],
        ]);

        $booking->status = BookingStatus::Cancelled;
        $booking->actor = Notifier::ACTOR_SALON;

        if (filled($data['reason'] ?? null)) {
            $note = 'سبب الإلغاء من الصالون: '.trim($data['reason']);
            $booking->notes = filled($booking->notes) ? $booking->notes."\n".$note : $note;
        }

        $booking->save();

        return $this->respond($salon, $booking, $request);
    }

    private function respond(Salon $salon, Booking $booking, Request $request): JsonResponse
    {
        $booking->load(self::RELATIONS);

        return response()->json([
            'data' => $this->present($booking, $request, $this->visitCounts($salon)),
        ]);
    }

    private function salon(Request $request): Salon
    {
        $user = User::findByBearer($request->bearerToken());

        abort_if($user === null, response()->json([
            'message' => 'يلزم تسجيل الدخول.',
        ], 401));

        $salon = $user->role === UserRole::Salon ? $user->salon : null;

        abort_if($salon === null, response()->json([
            'message' => 'هذا الحساب غير مرتبط بصالون.',
        ], 403));

        return $salon;
    }

    private function owned(Salon $salon, Booking $booking): void
    {
        abort_unless($booking->salon_id === $salon->id, response()->json([
            'message' => 'هذا الحجز لا يتبع صالونك.',
        ], 404));
    }

    private function moment(Booking $booking): Carbon
    {
        $day = $booking->booked_on?->toDateString() ?? now()->toDateString();

        return Carbon::parse($day.' '.($booking->booked_time ?? '00:00'));
    }

    private function canConfirm(Booking $booking): bool
    {
        return $booking->status === BookingStatus::Pending && $this->moment($booking)->isFuture();
    }

    private function canCancel(Booking $booking): bool
    {
        return in_array($booking->status, [BookingStatus::Pending, BookingStatus::Confirmed], true)
            && $this->moment($booking)->isFuture();
    }

    /**
     * @return array<string, int>
     */
    private function visitCounts(Salon $salon): array
    {
        return $salon->bookings()
            ->where('status', '!=', BookingStatus::Cancelled->value)
            ->selectRaw('customer_phone, count(*) as visits')
            ->groupBy('customer_phone')
            ->pluck('visits', 'customer_phone')
            ->map(fn ($count): int => (int) $count)
            ->all();
    }

    /**
     * @param  array<string, int>  $visits
     */
    private function present(Booking $booking, Request $request, array $visits): array
    {
        $customer = $booking->user;
        $host = $request->getSchemeAndHttpHost();
        $avatar = $customer?->avatar && Storage::disk('public')->exists($customer->avatar)
            ? $host.'/api/users/'.$customer->id.'/avatar'
            : null;

        return [
            'id' => $booking->id,
            'status' => $booking->status->value,
            'status_label' => $booking->status->getLabel(),
            'booked_on' => $booking->booked_on?->toDateString(),
            'booked_time' => $booking->booked_time,
            'created_at' => $booking->created_at?->toIso8601String(),
            'notes' => $booking->notes,
            'subtotal' => (float) $booking->subtotal,
            'discount_amount' => (float) $booking->discount_amount,
            'points_redeemed' => (int) $booking->points_redeemed,
            'points_discount' => (float) $booking->points_discount,
            'total' => (float) $booking->total,
            'payment_method' => $booking->payment_method,
            'payment_label' => $booking->paymentLabel(),
            'coupon_code' => $booking->coupon?->code,
            'can_confirm' => $this->canConfirm($booking),
            'can_cancel' => $this->canCancel($booking),
            'customer' => [
                'name' => $customer?->name ?: $booking->customer_name,
                'phone' => $booking->customer_phone ?: ($customer?->phone ?? ''),
                'email' => $customer?->email,
                'city' => $customer?->city,
                'address' => $customer?->address,
                'avatar_url' => $avatar,
                'registered' => $customer !== null,
                'visits' => $visits[$booking->customer_phone] ?? 0,
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
