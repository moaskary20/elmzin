<?php

namespace App\Http\Controllers\Api;

use App\Enums\UserRole;
use App\Enums\Weekday;
use App\Http\Controllers\Controller;
use App\Models\CatalogService;
use App\Models\Salon;
use App\Models\Service;
use App\Models\Specialist;
use App\Models\User;
use App\Models\WorkingHour;
use App\Services\SubscriptionService;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class SalonProfileController extends Controller
{
    private const DAYS = [6, 0, 1, 2, 3, 4, 5];

    public function show(Request $request): JsonResponse
    {
        return $this->respond($request, $this->salon($request));
    }

    public function update(Request $request): JsonResponse
    {
        $salon = $this->salon($request);

        $data = $request->validate([
            'name' => ['sometimes', 'required', 'string', 'max:255'],
            'phone' => ['sometimes', 'nullable', 'string', 'max:30'],
            'about' => ['sometimes', 'nullable', 'string', 'max:2000'],
            'city' => ['sometimes', 'required', 'string', 'max:120'],
            'district' => ['sometimes', 'nullable', 'string', 'max:120'],
            'address' => ['sometimes', 'required', 'string', 'max:255'],
            'latitude' => ['sometimes', 'nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['sometimes', 'nullable', 'numeric', 'between:-180,180'],
            'offers_home_service' => ['sometimes', 'boolean'],
        ], [
            'name.required' => 'اكتب اسم الصالون.',
            'city.required' => 'اكتب المدينة.',
            'address.required' => 'اكتب عنوان الصالون.',
        ]);

        $salon->update($data);

        return $this->respond($request, $salon);
    }

    public function storeService(Request $request): JsonResponse
    {
        $salon = $this->salon($request);

        $data = $request->validate([
            'catalog_service_id' => ['required', 'integer'],
            'price' => ['required', 'numeric', 'min:1', 'max:100000'],
            'duration_minutes' => ['nullable', 'integer', 'min:5', 'max:600'],
            'description' => ['nullable', 'string', 'max:1000'],
        ], [
            'catalog_service_id.required' => 'اختر الخدمة.',
            'price.required' => 'حدد سعر الخدمة.',
            'price.min' => 'السعر يجب أن يكون 1 على الأقل.',
        ]);

        $catalog = CatalogService::query()
            ->where('category_id', $salon->category_id)
            ->where('is_active', true)
            ->find($data['catalog_service_id']);

        if (! $catalog) {
            throw ValidationException::withMessages(['catalog_service_id' => 'هذه الخدمة غير متاحة لقسم صالونك.']);
        }

        if ($salon->services()->where('catalog_service_id', $catalog->id)->exists()) {
            throw ValidationException::withMessages(['catalog_service_id' => 'هذه الخدمة مضافة بالفعل.']);
        }

        if ($message = app(SubscriptionService::class)->limitReached($salon, 'services')) {
            throw ValidationException::withMessages(['catalog_service_id' => $message]);
        }

        $salon->services()->create([
            'catalog_service_id' => $catalog->id,
            'name' => $catalog->name,
            'price' => $data['price'],
            'duration_minutes' => $data['duration_minutes'] ?? $catalog->duration_minutes ?? 30,
            'description' => $data['description'] ?? null,
            'is_active' => true,
        ]);

        return $this->respond($request, $salon, 201);
    }

    public function updateService(Request $request, Service $service): JsonResponse
    {
        $salon = $this->salon($request);
        abort_unless($service->salon_id === $salon->id, 404);

        $data = $request->validate([
            'price' => ['sometimes', 'required', 'numeric', 'min:1', 'max:100000'],
            'duration_minutes' => ['sometimes', 'required', 'integer', 'min:5', 'max:600'],
            'description' => ['sometimes', 'nullable', 'string', 'max:1000'],
            'is_active' => ['sometimes', 'boolean'],
            'specialist_ids' => ['sometimes', 'array'],
            'specialist_ids.*' => ['integer', Rule::exists('specialists', 'id')->where('salon_id', $salon->id)],
        ], [
            'price.required' => 'حدد سعر الخدمة.',
            'price.min' => 'السعر يجب أن يكون 1 على الأقل.',
            'specialist_ids.*.exists' => 'الأخصائي غير موجود في صالونك.',
        ]);

        $service->update(collect($data)->except('specialist_ids')->all());

        if (array_key_exists('specialist_ids', $data)) {
            $service->specialists()->sync($data['specialist_ids']);
        }

        return $this->respond($request, $salon);
    }

    public function destroyService(Request $request, Service $service): JsonResponse
    {
        $salon = $this->salon($request);
        abort_unless($service->salon_id === $salon->id, 404);

        if ($service->bookings()->exists()) {
            throw ValidationException::withMessages([
                'service' => 'لا يمكن حذف خدمة لها حجوزات. يمكنك إخفاؤها بدلاً من ذلك.',
            ]);
        }

        $service->delete();

        return $this->respond($request, $salon);
    }

    public function storeSpecialist(Request $request): JsonResponse
    {
        $salon = $this->salon($request);

        if ($message = app(SubscriptionService::class)->limitReached($salon, 'specialists')) {
            throw ValidationException::withMessages(['name' => $message]);
        }

        $salon->specialists()->create([...$this->specialistData($request, true), 'is_active' => true]);

        return $this->respond($request, $salon, 201);
    }

    public function updateSpecialist(Request $request, Specialist $specialist): JsonResponse
    {
        $salon = $this->salon($request);
        abort_unless($specialist->salon_id === $salon->id, 404);

        $specialist->update($this->specialistData($request, false));

        return $this->respond($request, $salon);
    }

    public function destroySpecialist(Request $request, Specialist $specialist): JsonResponse
    {
        $salon = $this->salon($request);
        abort_unless($specialist->salon_id === $salon->id, 404);

        if ($specialist->bookings()->exists()) {
            throw ValidationException::withMessages([
                'specialist' => 'لا يمكن حذف أخصائي له حجوزات. يمكنك إيقافه بدلاً من ذلك.',
            ]);
        }

        $specialist->delete();

        return $this->respond($request, $salon);
    }

    public function updateHours(Request $request): JsonResponse
    {
        $salon = $this->salon($request);

        $data = $request->validate([
            'hours' => ['required', 'array', 'size:7'],
            'hours.*.day' => ['required', 'integer', 'between:0,6', 'distinct'],
            'hours.*.is_closed' => ['required', 'boolean'],
            'hours.*.opens_at' => ['nullable', 'required_if:hours.*.is_closed,false', 'date_format:H:i'],
            'hours.*.closes_at' => ['nullable', 'required_if:hours.*.is_closed,false', 'date_format:H:i'],
        ], [
            'hours.*.opens_at.required_if' => 'حدد وقت الفتح لكل يوم مفتوح.',
            'hours.*.closes_at.required_if' => 'حدد وقت الإغلاق لكل يوم مفتوح.',
            'hours.*.opens_at.date_format' => 'صيغة الوقت غير صحيحة.',
            'hours.*.closes_at.date_format' => 'صيغة الوقت غير صحيحة.',
        ]);

        foreach ($data['hours'] as $row) {
            if (! $row['is_closed'] && $row['closes_at'] <= $row['opens_at']) {
                throw ValidationException::withMessages([
                    'hours' => 'وقت الإغلاق يجب أن يكون بعد وقت الفتح يوم '.Weekday::from($row['day'])->getLabel().'.',
                ]);
            }
        }

        foreach ($data['hours'] as $row) {
            $salon->workingHours()->updateOrCreate(
                ['day_of_week' => $row['day']],
                [
                    'is_closed' => $row['is_closed'],
                    'opens_at' => $row['is_closed'] ? null : $row['opens_at'],
                    'closes_at' => $row['is_closed'] ? null : $row['closes_at'],
                ],
            );
        }

        return $this->respond($request, $salon);
    }

    /**
     * @return array<string, mixed>
     */
    private function specialistData(Request $request, bool $creating): array
    {
        $required = $creating ? 'required' : 'sometimes';

        return $request->validate([
            'name' => [$required, 'string', 'max:120'],
            'title' => ['sometimes', 'nullable', 'string', 'max:120'],
            'phone' => ['sometimes', 'nullable', 'string', 'max:30'],
            'is_active' => ['sometimes', 'boolean'],
        ], [
            'name.required' => 'اكتب اسم الأخصائي.',
        ]);
    }

    private function salon(Request $request): Salon
    {
        $user = User::findByBearer($request->bearerToken());

        abort_if($user === null, response()->json(['message' => 'يلزم تسجيل الدخول.'], 401));

        $salon = $user->role === UserRole::Salon ? $user->salon : null;

        abort_if($salon === null, response()->json(['message' => 'هذا الحساب غير مرتبط بصالون.'], 403));

        return $salon;
    }

    private function respond(Request $request, Salon $salon, int $status = 200): JsonResponse
    {
        $salon->refresh()->load(['category', 'services.specialists', 'specialists', 'workingHours']);
        $hours = $salon->workingHours->keyBy(fn (WorkingHour $hour): int => $hour->day_of_week->value);
        $taken = $salon->services->pluck('catalog_service_id')->filter()->all();

        return response()->json([
            'data' => [
                'id' => $salon->id,
                'name' => $salon->name,
                'phone' => $salon->phone,
                'about' => $salon->about,
                'city' => $salon->city,
                'district' => $salon->district,
                'address' => $salon->address,
                'latitude' => $salon->latitude === null ? null : (float) $salon->latitude,
                'longitude' => $salon->longitude === null ? null : (float) $salon->longitude,
                'offers_home_service' => (bool) $salon->offers_home_service,
                'verification_status' => $salon->verification_status?->value,
                'verification_label' => $salon->verification_status?->getLabel(),
                'category' => $salon->category?->name,
                'image_url' => $salon->image && Storage::disk('public')->exists($salon->image)
                    ? $request->getSchemeAndHttpHost().'/api/salons/'.$salon->id.'/image?v='.$salon->updated_at?->timestamp
                    : null,
                'services' => $salon->services->sortBy('name')->values()->map(fn (Service $service): array => [
                    'id' => $service->id,
                    'name' => $service->name,
                    'price' => (float) $service->price,
                    'duration_minutes' => (int) $service->duration_minutes,
                    'description' => $service->description,
                    'is_active' => (bool) $service->is_active,
                    'specialist_ids' => $service->specialists->pluck('id')->values(),
                ]),
                'specialists' => $salon->specialists->sortBy('name')->values()->map(fn (Specialist $specialist): array => [
                    'id' => $specialist->id,
                    'name' => $specialist->name,
                    'title' => $specialist->title,
                    'phone' => $specialist->phone,
                    'is_active' => (bool) $specialist->is_active,
                ]),
                'hours' => collect(self::DAYS)->map(function (int $day) use ($hours): array {
                    $hour = $hours->get($day);

                    return [
                        'day' => $day,
                        'label' => Weekday::from($day)->getLabel(),
                        'is_closed' => $hour === null || (bool) $hour->is_closed,
                        'opens_at' => $hour?->opens_at ? Carbon::parse($hour->opens_at)->format('H:i') : null,
                        'closes_at' => $hour?->closes_at ? Carbon::parse($hour->closes_at)->format('H:i') : null,
                    ];
                }),
            ],
            'subscription' => $salon->currentSubscription()->with('plan')->first()?->toApiArray(),
            'catalog' => CatalogService::query()
                ->where('category_id', $salon->category_id)
                ->where('is_active', true)
                ->whereNotIn('id', $taken)
                ->orderBy('sort_order')
                ->orderBy('name')
                ->get(['id', 'name', 'duration_minutes'])
                ->map(fn (CatalogService $item): array => [
                    'id' => $item->id,
                    'name' => $item->name,
                    'duration_minutes' => $item->duration_minutes,
                ]),
        ], $status);
    }
}
