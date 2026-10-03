<?php

namespace Database\Seeders;

use App\Enums\BookingStatus;
use App\Enums\CouponType;
use App\Enums\UserRole;
use App\Models\Booking;
use App\Models\Coupon;
use App\Models\LoyaltySetting;
use App\Models\Salon;
use App\Models\User;
use App\Services\OfferService;
use Illuminate\Database\Seeder;

class OffersSeeder extends Seeder
{
    public function run(): void
    {
        LoyaltySetting::current();

        $ahmed = User::query()->updateOrCreate(
            ['email' => 'ahmed@muzayen.test'],
            [
                'name' => 'أحمد سامي',
                'phone' => '01111111111',
                'password' => 'customer123',
                'role' => UserRole::Customer,
                'is_active' => true,
                'city' => 'القاهرة',
            ],
        );

        $sara = User::query()->updateOrCreate(
            ['email' => 'sara@muzayen.test'],
            [
                'name' => 'سارة علي',
                'phone' => '01222222222',
                'password' => 'customer123',
                'role' => UserRole::Customer,
                'is_active' => true,
                'city' => 'الجيزة',
            ],
        );

        if (! $sara->loyaltyTransactions()->where('note', 'رصيد ترحيبي')->exists()) {
            app(OfferService::class)->adjust($sara, 200, 'رصيد ترحيبي');
        }

        $welcome = Coupon::query()->updateOrCreate(
            ['code' => 'WELCOME20'],
            [
                'title' => 'ترحيب أول حجز',
                'description' => 'خصم ٢٠٪ على أول حجز، بحد أقصى ٥٠ ج.م.',
                'type' => CouponType::Percent,
                'value' => 20,
                'min_amount' => 0,
                'max_discount' => 50,
                'usage_limit' => 500,
                'usage_limit_per_user' => 1,
                'is_active' => true,
                'first_booking_only' => true,
            ],
        );
        $welcome->salons()->detach();

        $laythCoupon = Coupon::query()->updateOrCreate(
            ['code' => 'LAYTH50'],
            [
                'title' => 'خصم صالون الليث',
                'description' => '٥٠ ج.م على الطلبات من ١٠٠ ج.م داخل صالون الليث.',
                'type' => CouponType::Fixed,
                'value' => 50,
                'min_amount' => 100,
                'max_discount' => null,
                'usage_limit' => 200,
                'usage_limit_per_user' => 3,
                'is_active' => true,
                'first_booking_only' => false,
            ],
        );

        $salon = Salon::query()->where('name', 'صالون الليث')->first();

        if (! $salon) {
            return;
        }

        $laythCoupon->salons()->sync([$salon->id]);

        $existing = Booking::query()->where('customer_phone', '01111111111')->orderBy('id')->first();

        if ($existing && ! $existing->user_id) {
            $existing->user_id = $ahmed->id;
            $existing->save();
        }

        if (Booking::query()->where('notes', 'حجز تجريبي لنقاط الولاء')->exists()) {
            return;
        }

        $service = $salon->services()->where('name', 'قص شعر')->first();
        $specialist = $salon->specialists()->where('name', 'كريم محمود')->first();

        if (! $service || ! $specialist) {
            return;
        }

        Booking::query()->create([
            'salon_id' => $salon->id,
            'specialist_id' => $specialist->id,
            'service_id' => $service->id,
            'user_id' => $ahmed->id,
            'coupon_id' => $laythCoupon->id,
            'customer_name' => $ahmed->name,
            'customer_phone' => $ahmed->phone,
            'booked_on' => now()->subDay()->toDateString(),
            'booked_time' => '16:00',
            'status' => BookingStatus::Completed,
            'notes' => 'حجز تجريبي لنقاط الولاء',
            'points_redeemed' => 0,
        ]);
    }
}
