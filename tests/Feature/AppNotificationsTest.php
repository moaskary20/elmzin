<?php

namespace Tests\Feature;

use App\Enums\BookingStatus;
use App\Enums\UserRole;
use App\Enums\VerificationStatus;
use App\Enums\WalletTransactionType;
use App\Models\AppNotification;
use App\Models\Booking;
use App\Models\Category;
use App\Models\Review;
use App\Models\Salon;
use App\Models\User;
use App\Services\OfferService;
use App\Services\WalletService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

class AppNotificationsTest extends TestCase
{
    use RefreshDatabase;

    private User $owner;

    private User $customer;

    private Salon $salon;

    protected function setUp(): void
    {
        parent::setUp();

        $category = Category::query()->create(['name' => 'رجالي', 'slug' => 'men', 'is_active' => true]);
        $this->owner = $this->user('owner@test.local', '0100', UserRole::Salon);
        $this->customer = $this->user('client@test.local', '0111', UserRole::Customer);
        $this->salon = Salon::query()->create([
            'category_id' => $category->id,
            'user_id' => $this->owner->id,
            'name' => 'صالون الأناقة',
            'phone' => '0100',
            'city' => 'القاهرة',
            'address' => 'شارع',
            'latitude' => 30,
            'longitude' => 31,
            'verification_status' => VerificationStatus::Pending,
            'is_active' => true,
        ]);
    }

    public function test_new_accounts_get_a_welcome_notice(): void
    {
        $this->assertSame(['welcome'], $this->types($this->customer));
        $this->assertStringContainsString('قيد المراجعة', AppNotification::query()->where('user_id', $this->owner->id)->value('body'));
    }

    public function test_booking_lifecycle_notifies_both_sides(): void
    {
        $booking = $this->booking();

        $this->assertContains('booking_created', $this->types($this->customer));
        $this->assertContains('booking_new', $this->types($this->owner));

        $this->withToken($this->tokenFor($this->owner))
            ->postJson("/api/salon/bookings/{$booking->id}/confirm")->assertOk();
        $this->assertContains('booking_confirmed', $this->types($this->customer));
        $this->assertNotContains('booking_confirmed', $this->types($this->owner));

        $booking->refresh();
        $booking->booked_time = '15:30';
        $booking->save();
        $this->assertContains('booking_rescheduled', $this->types($this->customer));
        $this->assertContains('booking_rescheduled', $this->types($this->owner));

        $booking->status = BookingStatus::Completed;
        $booking->save();
        $this->assertContains('booking_completed', $this->types($this->customer));
        $this->assertContains('booking_completed', $this->types($this->owner));

        Review::query()->create([
            'salon_id' => $this->salon->id,
            'booking_id' => $booking->id,
            'customer_name' => 'client',
            'rating' => 4,
            'comment' => 'ممتاز',
            'is_visible' => true,
        ]);
        $review = AppNotification::query()->where('user_id', $this->owner->id)->where('type', 'review_new')->first();
        $this->assertNotNull($review);
        $this->assertStringContainsString('★★★★', $review->title);

        $before = AppNotification::query()->count();
        $booking->refresh()->save();
        $this->assertSame($before, AppNotification::query()->count());
    }

    public function test_cancellation_notifies_the_other_party_only(): void
    {
        $first = $this->booking();
        $this->withToken($this->tokenFor($this->owner))
            ->postJson("/api/salon/bookings/{$first->id}/cancel", ['reason' => 'الأخصائي غير متاح'])->assertOk();

        $notice = AppNotification::query()->where('user_id', $this->customer->id)->where('type', 'booking_cancelled')->first();
        $this->assertStringContainsString('الأخصائي غير متاح', $notice->body);
        $this->assertNotContains('booking_cancelled', $this->types($this->owner));

        $second = $this->booking('13:00');
        $this->withToken($this->tokenFor($this->customer))
            ->postJson("/api/account/bookings/{$second->id}/cancel")->assertOk();

        $this->assertSame(1, AppNotification::query()->where('user_id', $this->owner->id)->where('type', 'booking_cancelled')->count());
        $this->assertSame(1, AppNotification::query()->where('user_id', $this->customer->id)->where('type', 'booking_cancelled')->count());
    }

    public function test_verification_wallet_and_points_notify(): void
    {
        $this->salon->update(['verification_status' => VerificationStatus::Verified]);
        $this->assertContains('salon_verified', $this->types($this->owner));

        app(WalletService::class)->post($this->customer, WalletTransactionType::Deposit, 200, 'شحن تجريبي');
        app(OfferService::class)->adjust($this->customer->fresh(), 50, 'هدية');

        $types = $this->types($this->customer);
        $this->assertContains('wallet', $types);
        $this->assertContains('loyalty', $types);
    }

    public function test_api_lists_and_marks_notifications_read(): void
    {
        $this->booking();
        $token = $this->tokenFor($this->customer);

        $this->getJson('/api/notifications')->assertStatus(401);

        $list = $this->withToken($token)->getJson('/api/notifications')
            ->assertOk()
            ->assertJsonPath('unread', 2)
            ->assertJsonPath('data.0.type', 'booking_created')
            ->assertJsonPath('data.0.read', false);

        $id = $list->json('data.0.id');
        $this->withToken($token)->postJson("/api/notifications/{$id}/read")
            ->assertOk()
            ->assertJsonPath('data.read', true)
            ->assertJsonPath('unread', 1);

        $foreign = AppNotification::query()->where('user_id', $this->owner->id)->value('id');
        $this->withToken($token)->postJson("/api/notifications/{$foreign}/read")->assertStatus(404);

        $this->withToken($token)->postJson('/api/notifications/read-all')->assertOk()->assertJsonPath('unread', 0);
        $this->withToken($token)->getJson('/api/notifications')->assertJsonPath('unread', 0);
    }

    /** @return list<string> */
    private function types(User $user): array
    {
        return AppNotification::query()->where('user_id', $user->id)->pluck('type')->all();
    }

    private function booking(string $time = '12:00'): Booking
    {
        $service = $this->salon->services()->firstOrCreate(['name' => 'قص شعر'], ['price' => 150, 'duration_minutes' => 30, 'is_active' => true]);

        $specialist = $this->salon->specialists()->firstOrCreate(['name' => 'أحمد'], ['title' => 'حلاق', 'is_active' => true]);

        return Booking::query()->create([
            'salon_id' => $this->salon->id,
            'service_id' => $service->id,
            'specialist_id' => $specialist->id,
            'user_id' => $this->customer->id,
            'customer_name' => 'client',
            'customer_phone' => '0111',
            'booked_on' => now()->addDays(2)->toDateString(),
            'booked_time' => $time,
            'status' => BookingStatus::Pending,
        ]);
    }

    private function user(string $email, string $phone, UserRole $role): User
    {
        return User::query()->create([
            'name' => Str::before($email, '@'),
            'email' => $email,
            'phone' => $phone,
            'password' => 'secret12',
            'role' => $role,
            'is_active' => true,
        ]);
    }

    private function tokenFor(User $user): string
    {
        $raw = Str::random(60);
        $user->forceFill(['api_token' => hash('sha256', $raw)])->save();

        return $raw;
    }
}
