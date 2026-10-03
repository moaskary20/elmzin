<?php

namespace App\Http\Controllers\Api;

use App\Enums\BookingStatus;
use App\Enums\VerificationStatus;
use App\Http\Controllers\Controller;
use App\Models\Booking;
use App\Models\Salon;
use App\Models\Service;
use App\Models\Specialist;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\ValidationException;

class SalonController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $salons = Salon::query()
            ->where('is_active', true)
            ->with([
                'category:id,name,slug',
                'services' => fn ($query) => $query->where('is_active', true)->select('id', 'salon_id', 'name'),
            ])
            ->withMin(['services as min_price' => function ($query): void {
                $query->where('is_active', true);
            }], 'price')
            ->withMax(['services as max_price' => function ($query): void {
                $query->where('is_active', true);
            }], 'price')
            ->orderByDesc('is_featured')
            ->orderByDesc('rating_avg')
            ->orderBy('id')
            ->get()
            ->map(fn (Salon $salon): array => [
                'id' => $salon->id,
                'name' => $salon->name,
                'image_url' => $this->imageUrl($request, $salon),
                'city' => $salon->city,
                'district' => $salon->district,
                'address' => $salon->address,
                'category' => $salon->category?->name,
                'category_slug' => $salon->category?->slug,
                'rating_avg' => (float) $salon->rating_avg,
                'reviews_count' => $salon->reviews_count,
                'is_featured' => (bool) $salon->is_featured,
                'offers_home_service' => (bool) $salon->offers_home_service,
                'latitude' => $salon->latitude,
                'longitude' => $salon->longitude,
                'min_price' => $salon->min_price !== null ? (float) $salon->min_price : null,
                'max_price' => $salon->max_price !== null ? (float) $salon->max_price : null,
                'verified' => $salon->verification_status === VerificationStatus::Verified,
                'services' => $salon->services->pluck('name')->values(),
            ])
            ->values();

        return response()->json(['data' => $salons]);
    }

    public function services(Request $request): JsonResponse
    {
        $services = Service::query()
            ->where('is_active', true)
            ->whereHas('salon', fn ($query) => $query->where('is_active', true))
            ->with('salon.category:id,name,slug')
            ->withCount(['bookings' => fn ($query) => $query->where('status', '!=', BookingStatus::Cancelled->value)])
            ->orderBy('name')
            ->orderBy('price')
            ->get()
            ->map(fn (Service $service): array => [
                'id' => $service->id,
                'name' => $service->name,
                'description' => $service->description,
                'price' => (float) $service->price,
                'duration_minutes' => $service->duration_minutes,
                'bookings_count' => $service->bookings_count,
                'salon' => [
                    'id' => $service->salon->id,
                    'name' => $service->salon->name,
                    'city' => $service->salon->city,
                    'district' => $service->salon->district,
                    'category_slug' => $service->salon->category?->slug,
                    'rating_avg' => (float) $service->salon->rating_avg,
                    'offers_home_service' => (bool) $service->salon->offers_home_service,
                    'verified' => $service->salon->verification_status === VerificationStatus::Verified,
                    'image_url' => $this->imageUrl($request, $service->salon),
                ],
            ])
            ->values();

        return response()->json(['data' => $services]);
    }

    public function show(Request $request, Salon $salon): JsonResponse
    {
        abort_unless($salon->is_active, 404);

        $salon->load([
            'category:id,name,slug',
            'workingHours',
            'services' => fn ($query) => $query->where('is_active', true)->orderBy('price')->orderBy('id'),
            'services.specialists:id',
            'specialists' => fn ($query) => $query->where('is_active', true)->orderBy('id'),
            'reviews' => fn ($query) => $query->where('is_visible', true)->latest(),
        ]);

        $booked = Booking::query()
            ->where('salon_id', $salon->id)
            ->whereDate('booked_on', '>=', today())
            ->where('status', '!=', BookingStatus::Cancelled->value)
            ->get(['specialist_id', 'booked_on', 'booked_time']);

        return response()->json([
            'data' => [
                'id' => $salon->id,
                'name' => $salon->name,
                'image_url' => $this->imageUrl($request, $salon),
                'about' => $salon->about,
                'city' => $salon->city,
                'district' => $salon->district,
                'address' => $salon->address,
                'category' => $salon->category?->name,
                'category_slug' => $salon->category?->slug,
                'rating_avg' => (float) $salon->rating_avg,
                'reviews_count' => $salon->reviews_count,
                'verified' => $salon->verification_status === VerificationStatus::Verified,
                'hours' => $salon->workingHours->map(fn ($hour): array => [
                    'day' => $hour->day_of_week->value,
                    'opens_at' => $this->clock($hour->opens_at),
                    'closes_at' => $this->clock($hour->closes_at),
                    'is_closed' => (bool) $hour->is_closed,
                ])->values(),
                'services' => $salon->services->map(fn (Service $service): array => [
                    'id' => $service->id,
                    'name' => $service->name,
                    'price' => (float) $service->price,
                    'duration_minutes' => $service->duration_minutes,
                    'specialist_ids' => $service->specialists->pluck('id')->values(),
                ])->values(),
                'specialists' => $salon->specialists->map(fn (Specialist $specialist): array => [
                    'id' => $specialist->id,
                    'name' => $specialist->name,
                    'title' => $specialist->title,
                ])->values(),
                'reviews' => $salon->reviews->map(fn ($review): array => [
                    'customer_name' => $review->customer_name,
                    'rating' => $review->rating,
                    'comment' => $review->comment,
                    'created_at' => $review->created_at?->toDateString(),
                ])->values(),
                'booked' => $booked->map(fn (Booking $booking): array => [
                    'specialist_id' => $booking->specialist_id,
                    'date' => $booking->booked_on?->toDateString(),
                    'time' => $booking->booked_time,
                ])->values(),
            ],
        ]);
    }

    public function storeBooking(Request $request, Salon $salon): JsonResponse
    {
        abort_unless($salon->is_active, 404);

        $validated = $request->validate([
            'service_id' => ['required', 'integer'],
            'specialist_id' => ['nullable', 'integer'],
            'booked_on' => ['required', 'date', 'after_or_equal:today'],
            'booked_time' => ['required', 'date_format:H:i'],
            'customer_name' => ['required', 'string', 'max:255'],
            'customer_phone' => ['required', 'string', 'max:30'],
            'payment_method' => ['nullable', 'in:cash,card'],
            'card_last4' => ['nullable', 'required_if:payment_method,card', 'digits:4'],
        ], [
            'payment_method.in' => 'طريقة الدفع غير معروفة.',
            'card_last4.required_if' => 'بيانات البطاقة غير مكتملة.',
            'card_last4.digits' => 'بيانات البطاقة غير صحيحة.',
        ]);

        $payment = $validated['payment_method'] ?? 'cash';

        $service = $salon->services()
            ->where('is_active', true)
            ->find($validated['service_id']);

        if (! $service) {
            throw ValidationException::withMessages([
                'service_id' => 'الخدمة غير متاحة في هذا الصالون.',
            ]);
        }

        $salon->load('workingHours');
        $day = Carbon::parse($validated['booked_on'])->dayOfWeek;
        $hour = $salon->workingHours->first(
            fn ($row): bool => $row->day_of_week->value === $day && ! $row->is_closed,
        );

        $opens = $hour ? $this->clock($hour->opens_at) : null;
        $closes = $hour ? $this->clock($hour->closes_at) : null;
        $time = $validated['booked_time'];

        if (! $opens || ! $closes || ! $this->insideHours($time, $opens, $closes)) {
            throw ValidationException::withMessages([
                'booked_time' => 'هذا الوقت خارج ساعات العمل.',
            ]);
        }

        $moment = Carbon::parse($validated['booked_on'].' '.$time);

        if ($moment->lt(now())) {
            throw ValidationException::withMessages([
                'booked_time' => 'لا يمكن حجز وقت مضى.',
            ]);
        }

        $specialists = $service->specialists()->where('is_active', true)->get();

        if ($specialists->isEmpty()) {
            $specialists = $salon->specialists()->where('is_active', true)->get();
        }

        $requested = $validated['specialist_id'] ?? null;

        if ($requested) {
            $specialist = $specialists->firstWhere('id', (int) $requested);

            if (! $specialist) {
                throw ValidationException::withMessages([
                    'specialist_id' => 'الأخصائي غير متاح لهذه الخدمة.',
                ]);
            }

            if ($this->isBooked($specialist, $validated['booked_on'], $time)) {
                throw ValidationException::withMessages([
                    'booked_time' => 'هذا الوقت محجوز.',
                ]);
            }
        } else {
            $specialist = $specialists->first(
                fn (Specialist $candidate): bool => ! $this->isBooked($candidate, $validated['booked_on'], $time),
            );

            if (! $specialist) {
                throw ValidationException::withMessages([
                    'booked_time' => 'لا يوجد أخصائي متاح في هذا الوقت.',
                ]);
            }
        }

        $account = User::findByBearer($request->bearerToken());

        $booking = Booking::query()->create([
            'salon_id' => $salon->id,
            'specialist_id' => $specialist->id,
            'service_id' => $service->id,
            'user_id' => $account?->id,
            'customer_name' => $validated['customer_name'],
            'customer_phone' => $validated['customer_phone'],
            'booked_on' => $validated['booked_on'],
            'booked_time' => $time,
            'status' => BookingStatus::Pending,
            'payment_method' => $payment,
            'card_last4' => $payment === 'card' ? $validated['card_last4'] : null,
            'points_redeemed' => 0,
        ]);

        return response()->json([
            'data' => [
                'id' => $booking->id,
                'message' => 'تم تسجيل الحجز.',
            ],
        ], 201);
    }

    public function image(Salon $salon)
    {
        abort_unless(
            $salon->is_active && $salon->image && Storage::disk('public')->exists($salon->image),
            404,
        );

        return response()->file(Storage::disk('public')->path($salon->image));
    }

    private function imageUrl(Request $request, Salon $salon): ?string
    {
        if (! $salon->image || ! Storage::disk('public')->exists($salon->image)) {
            return null;
        }

        return $request->getSchemeAndHttpHost().'/api/salons/'.$salon->id.'/image';
    }

    private function clock(mixed $value): ?string
    {
        if ($value === null || $value === '') {
            return null;
        }

        return Carbon::parse((string) $value)->format('H:i');
    }

    private function insideHours(string $time, string $opens, string $closes): bool
    {
        $minutes = $this->minutes($time);

        return $minutes >= $this->minutes($opens) && $minutes + 30 <= $this->minutes($closes);
    }

    private function minutes(string $clock): int
    {
        [$hour, $minute] = array_pad(explode(':', $clock), 2, '0');

        return ((int) $hour) * 60 + (int) $minute;
    }

    private function isBooked(Specialist $specialist, string $date, string $time): bool
    {
        return Booking::query()
            ->where('specialist_id', $specialist->id)
            ->whereDate('booked_on', $date)
            ->where('status', '!=', BookingStatus::Cancelled->value)
            ->where('booked_time', Carbon::parse($time)->format('H:i:s'))
            ->exists();
    }
}
