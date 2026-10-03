<?php

namespace App\Http\Controllers\Api;

use App\Enums\UserRole;
use App\Enums\VerificationStatus;
use App\Enums\Weekday;
use App\Http\Controllers\Controller;
use App\Models\CatalogService;
use App\Models\Salon;
use App\Models\SubscriptionPlan;
use App\Models\User;
use App\Services\Notifier;
use App\Services\SubscriptionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    private const RESET_MINUTES = 15;

    public function register(Request $request): JsonResponse
    {
        $data = $request->validate([
            'account_type' => ['required', Rule::in(['customer', 'salon'])],
            'name' => ['required', 'string', 'max:120'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'phone' => ['required', 'string', 'max:30', 'unique:users,phone'],
            'password' => ['required', 'string', 'min:6', 'max:100'],
            'address' => ['required', 'string', 'max:255'],
            'city' => ['nullable', 'string', 'max:120'],
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
            'notifications' => ['sometimes', 'boolean'],
            'dark_mode' => ['sometimes', 'boolean'],
            'locale' => ['sometimes', Rule::in(['ar', 'en'])],
            'category_id' => [
                'required_if:account_type,salon',
                'nullable',
                'integer',
                Rule::exists('categories', 'id')->where('is_active', true),
            ],
            'services' => ['required_if:account_type,salon', 'array', 'min:1'],
            'services.*.id' => ['required', 'integer', 'distinct'],
            'services.*.price' => ['required', 'numeric', 'min:1', 'max:100000'],
            'plan_id' => [
                'nullable',
                'integer',
                Rule::exists('subscription_plans', 'id')->where('is_active', true),
            ],
            'accept_terms' => ['exclude_without:plan_id', 'required', 'accepted'],
            'specialists' => ['sometimes', 'array', 'max:50'],
            'specialists.*.name' => ['required', 'string', 'max:120'],
            'specialists.*.title' => ['nullable', 'string', 'max:120'],
            'specialists.*.phone' => ['nullable', 'string', 'max:30'],
            'hours' => ['sometimes', 'array', 'size:7'],
            'hours.*.day' => ['required', 'integer', 'between:0,6', 'distinct'],
            'hours.*.is_closed' => ['required', 'boolean'],
            'hours.*.opens_at' => ['nullable', 'required_if:hours.*.is_closed,false', 'date_format:H:i'],
            'hours.*.closes_at' => ['nullable', 'required_if:hours.*.is_closed,false', 'date_format:H:i'],
        ], [
            'specialists.*.name.required' => 'اكتب اسم كل أخصائي.',
            'hours.size' => 'حدد مواعيد العمل لكل أيام الأسبوع.',
            'hours.*.opens_at.required_if' => 'حدد وقت الفتح لكل يوم مفتوح.',
            'hours.*.closes_at.required_if' => 'حدد وقت الإغلاق لكل يوم مفتوح.',
            'hours.*.opens_at.date_format' => 'صيغة الوقت غير صحيحة.',
            'hours.*.closes_at.date_format' => 'صيغة الوقت غير صحيحة.',
            'plan_id.exists' => 'هذه الباقة غير متاحة.',
            'accept_terms.required' => 'يجب الموافقة على قوانين الاشتراك.',
            'accept_terms.accepted' => 'يجب الموافقة على قوانين الاشتراك.',
            'category_id.required_if' => 'اختر قسم الصالون.',
            'category_id.exists' => 'القسم غير متاح.',
            'services.required_if' => 'اختر خدمة واحدة على الأقل.',
            'services.min' => 'اختر خدمة واحدة على الأقل.',
            'services.*.price.required' => 'حدد سعر كل خدمة مختارة.',
            'services.*.price.numeric' => 'سعر الخدمة يجب أن يكون رقماً.',
            'services.*.price.min' => 'سعر الخدمة يجب أن يكون أكبر من صفر.',
            'email.unique' => 'هذا البريد مستخدم بالفعل.',
            'phone.unique' => 'رقم الهاتف مستخدم بالفعل.',
            'password.min' => 'كلمة المرور يجب أن تكون ٦ أحرف على الأقل.',
            'address.required' => 'حدد العنوان من الخريطة.',
        ]);

        $role = $data['account_type'] === 'salon' ? UserRole::Salon : UserRole::Customer;
        $catalog = collect();
        $prices = [];

        $plan = null;

        if ($role === UserRole::Salon) {
            $plan = filled($data['plan_id'] ?? null)
                ? SubscriptionPlan::query()->find($data['plan_id'])
                : SubscriptionPlan::query()->available()->first();

            if ($plan?->max_services && count($data['services']) > $plan->max_services) {
                throw ValidationException::withMessages([
                    'services' => "باقة {$plan->name} تسمح بحد أقصى {$plan->max_services} خدمة.",
                ]);
            }

            if ($plan?->max_specialists && count($data['specialists'] ?? []) > $plan->max_specialists) {
                throw ValidationException::withMessages([
                    'specialists' => "باقة {$plan->name} تسمح بحد أقصى {$plan->max_specialists} أخصائي.",
                ]);
            }

            foreach ($data['hours'] ?? [] as $row) {
                if (! $row['is_closed'] && $row['closes_at'] <= $row['opens_at']) {
                    throw ValidationException::withMessages([
                        'hours' => 'وقت الإغلاق يجب أن يكون بعد وقت الفتح يوم '.Weekday::from($row['day'])->getLabel().'.',
                    ]);
                }
            }

            $prices = collect($data['services'])
                ->mapWithKeys(fn (array $item): array => [(int) $item['id'] => (float) $item['price']])
                ->all();
            $ids = array_keys($prices);
            $catalog = CatalogService::query()
                ->where('category_id', $data['category_id'])
                ->where('is_active', true)
                ->whereIn('id', $ids)
                ->get();

            if ($catalog->count() !== count($ids)) {
                throw ValidationException::withMessages([
                    'services' => 'بعض الخدمات المختارة لا تتبع هذا القسم.',
                ]);
            }
        }

        $user = DB::transaction(function () use ($data, $role, $request, $catalog, $prices, $plan): User {
            $user = User::query()->create([
                'name' => $data['name'],
                'email' => $data['email'],
                'phone' => $data['phone'],
                'password' => $data['password'],
                'role' => $role,
                'is_active' => true,
                'city' => $data['city'] ?? null,
                'address' => $data['address'],
                'latitude' => $data['latitude'],
                'longitude' => $data['longitude'],
                'notifications_enabled' => $request->boolean('notifications', true),
                'dark_mode' => $request->boolean('dark_mode', true),
                'locale' => $data['locale'] ?? 'ar',
            ]);

            if ($role === UserRole::Salon) {
                $salon = Salon::query()->create([
                    'category_id' => $data['category_id'],
                    'user_id' => $user->id,
                    'name' => $user->name,
                    'phone' => $user->phone,
                    'city' => $user->city ?: 'غير محدد',
                    'address' => $user->address,
                    'latitude' => $user->latitude,
                    'longitude' => $user->longitude,
                    'about' => 'طلب انضمام من تطبيق الموبايل.',
                    'verification_status' => VerificationStatus::Pending,
                    'is_active' => true,
                ]);

                if ($plan) {
                    app(SubscriptionService::class)->subscribe(
                        $salon,
                        $plan,
                        termsAccepted: (bool) ($data['accept_terms'] ?? false),
                    );
                }

                $services = [];
                foreach ($catalog as $item) {
                    $services[] = $salon->services()->create([
                        'catalog_service_id' => $item->id,
                        'name' => $item->name,
                        'description' => $item->description,
                        'price' => $prices[$item->id],
                        'duration_minutes' => $item->duration_minutes,
                        'is_active' => true,
                    ])->id;
                }

                foreach ($data['specialists'] ?? [] as $person) {
                    $salon->specialists()->create([
                        'name' => trim($person['name']),
                        'title' => filled($person['title'] ?? null) ? trim($person['title']) : null,
                        'phone' => filled($person['phone'] ?? null) ? trim($person['phone']) : null,
                        'is_active' => true,
                    ])->services()->sync($services);
                }

                foreach ($data['hours'] ?? [] as $row) {
                    $salon->workingHours()->create([
                        'day_of_week' => $row['day'],
                        'is_closed' => $row['is_closed'],
                        'opens_at' => $row['is_closed'] ? null : $row['opens_at'],
                        'closes_at' => $row['is_closed'] ? null : $row['closes_at'],
                    ]);
                }
            }

            return $user;
        });

        return response()->json([
            'token' => $this->issueToken($user),
            'data' => $user->toAccountArray($request->getSchemeAndHttpHost()),
        ], 201);
    }

    public function login(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        $user = User::query()->where('email', $data['email'])->first();

        if (! $user || ! $user->is_active || ! Hash::check($data['password'], $user->password)) {
            throw ValidationException::withMessages([
                'email' => 'بيانات الدخول غير صحيحة.',
            ]);
        }

        return response()->json([
            'token' => $this->issueToken($user),
            'data' => $user->toAccountArray($request->getSchemeAndHttpHost()),
        ]);
    }

    public function forgotPassword(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => ['required', 'email'],
        ], [
            'email.required' => 'أدخل البريد الإلكتروني.',
            'email.email' => 'أدخل بريداً صحيحاً.',
        ]);

        $user = User::query()
            ->where('email', $data['email'])
            ->where('is_active', true)
            ->first();

        if ($user) {
            $code = (string) random_int(100000, 999999);

            DB::table('password_reset_tokens')->updateOrInsert(
                ['email' => $user->email],
                ['token' => Hash::make($code), 'created_at' => now()],
            );

            Mail::raw(
                "مرحباً {$user->name}،\n\nرمز استعادة كلمة المرور في تطبيق المزين هو: {$code}\n\nالرمز صالح لمدة ".self::RESET_MINUTES.' دقيقة. إذا لم تطلب ذلك فتجاهل هذه الرسالة.',
                fn ($message) => $message->to($user->email)->subject('رمز استعادة كلمة المرور - المزين'),
            );
        }

        return response()->json([
            'message' => 'إذا كان البريد مسجلاً فستصلك رسالة برمز الاستعادة.',
        ]);
    }

    public function resetPassword(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => ['required', 'email'],
            'code' => ['required', 'digits:6'],
            'password' => ['required', 'string', 'min:6', 'max:100', 'confirmed'],
        ], [
            'code.required' => 'أدخل رمز الاستعادة.',
            'code.digits' => 'الرمز مكوّن من ٦ أرقام.',
            'password.min' => 'كلمة المرور يجب أن تكون ٦ أحرف على الأقل.',
            'password.confirmed' => 'تأكيد كلمة المرور غير مطابق.',
        ]);

        $row = DB::table('password_reset_tokens')->where('email', $data['email'])->first();
        $user = User::query()
            ->where('email', $data['email'])
            ->where('is_active', true)
            ->first();

        $expired = ! $row || ! $row->created_at
            || now()->diffInMinutes($row->created_at, true) > self::RESET_MINUTES;

        if (! $user || $expired || ! Hash::check($data['code'], $row->token)) {
            throw ValidationException::withMessages([
                'code' => 'الرمز غير صحيح أو انتهت صلاحيته.',
            ]);
        }

        $user->password = $data['password'];
        $user->save();
        app(Notifier::class)->passwordChanged($user);
        DB::table('password_reset_tokens')->where('email', $user->email)->delete();

        return response()->json([
            'message' => 'تم تغيير كلمة المرور.',
            'token' => $this->issueToken($user),
            'data' => $user->toAccountArray($request->getSchemeAndHttpHost()),
        ]);
    }

    private function issueToken(User $user): string
    {
        $plain = Str::random(48);
        $user->forceFill(['api_token' => hash('sha256', $plain)])->save();

        return $plain;
    }
}
