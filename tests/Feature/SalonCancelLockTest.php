<?php

namespace Tests\Feature;

use App\Enums\BookingStatus;
use App\Enums\UserRole;
use App\Enums\VerificationStatus;
use App\Models\Booking;
use App\Models\BookingSetting;
use App\Models\Category;
use App\Models\Salon;
use App\Models\Service;
use App\Models\Specialist;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SalonCancelLockTest extends TestCase
{
    use RefreshDatabase;

    public function test_confirmed_booking_cannot_be_cancelled_inside_admin_hours_window(): void
    {
        BookingSetting::current()->update([
            'salon_cancel_lock_enabled' => true,
            'salon_cancel_hours_before' => 3,
        ]);

        [$token, $booking] = $this->confirmedBookingSoon(hoursFromNow: 1);

        $this->withToken($token)
            ->getJson('/api/salon/bookings')
            ->assertOk()
            ->assertJsonPath('data.0.can_cancel', false)
            ->assertJsonPath('data.0.cancel_locked', true)
            ->assertJsonPath(
                'data.0.cancel_lock_message',
                'لا يمكن إلغاء الطلب قبل الموعد بأقل من 3 ساعة حسب إعدادات الإدارة.'
            );

        $this->withToken($token)
            ->postJson("/api/salon/bookings/{$booking->id}/cancel", ['reason' => 'ظرف'])
            ->assertStatus(422)
            ->assertJsonValidationErrors('status');
    }

    public function test_confirmed_booking_can_be_cancelled_outside_the_window(): void
    {
        BookingSetting::current()->update([
            'salon_cancel_lock_enabled' => true,
            'salon_cancel_hours_before' => 2,
        ]);

        [$token, $booking] = $this->confirmedBookingSoon(hoursFromNow: 5);

        $this->withToken($token)
            ->postJson("/api/salon/bookings/{$booking->id}/cancel", ['reason' => 'ظرف'])
            ->assertOk()
            ->assertJsonPath('data.status', 'cancelled');
    }

    /**
     * @return array{0: string, 1: Booking}
     */
    private function confirmedBookingSoon(int $hoursFromNow): array
    {
        $owner = User::query()->create([
            'name' => 'صاحب صالون',
            'email' => 'owner-cancel@test.local',
            'phone' => '01055554444',
            'password' => 'secret12',
            'role' => UserRole::Salon,
            'is_active' => true,
        ]);

        $category = Category::query()->create(['name' => 'رجالي', 'slug' => 'men', 'is_active' => true]);
        $salon = Salon::query()->create([
            'category_id' => $category->id,
            'user_id' => $owner->id,
            'name' => 'صالون الإلغاء',
            'phone' => $owner->phone,
            'city' => 'القاهرة',
            'address' => 'شارع',
            'verification_status' => VerificationStatus::Verified,
            'is_active' => true,
        ]);
        $service = Service::query()->create([
            'salon_id' => $salon->id,
            'name' => 'قص',
            'price' => 100,
            'duration_minutes' => 30,
            'is_active' => true,
        ]);
        $specialist = Specialist::query()->create([
            'salon_id' => $salon->id,
            'name' => 'حلاق',
            'is_active' => true,
        ]);

        $when = now()->addHours($hoursFromNow);
        $booking = Booking::query()->create([
            'salon_id' => $salon->id,
            'specialist_id' => $specialist->id,
            'service_id' => $service->id,
            'customer_name' => 'عميل',
            'customer_phone' => '01022223333',
            'booked_on' => $when->toDateString(),
            'booked_time' => $when->format('H:i'),
            'status' => BookingStatus::Confirmed,
            'subtotal' => 100,
            'total' => 100,
            'payment_method' => 'cash',
        ]);

        $raw = 'salon-cancel-token';
        $owner->forceFill(['api_token' => hash('sha256', $raw)])->save();

        return [$raw, $booking];
    }
}
