<?php

namespace Tests\Feature;

use App\Enums\BookingStatus;
use App\Enums\UserRole;
use App\Models\Booking;
use App\Models\Category;
use App\Models\Salon;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

class SalonBookingsTest extends TestCase
{
    use RefreshDatabase;

    private string $token;

    private Salon $salon;

    private Booking $upcoming;

    protected function setUp(): void
    {
        parent::setUp();

        $category = Category::query()->create(['name' => 'رجالي', 'slug' => 'men', 'is_active' => true]);
        $owner = $this->user('owner@test.local', '0100', UserRole::Salon);
        $this->token = $this->tokenFor($owner);
        $this->salon = Salon::query()->create([
            'category_id' => $category->id,
            'user_id' => $owner->id,
            'name' => 'صالون الأناقة',
            'phone' => '0100',
            'city' => 'القاهرة',
            'address' => 'شارع',
            'latitude' => 30,
            'longitude' => 31,
            'is_active' => true,
        ]);
        $customer = $this->user('client@test.local', '0111', UserRole::Customer);

        $this->upcoming = $this->booking($this->salon, $customer, now()->addDay(), BookingStatus::Pending, 'يفضل المقص');
        $this->booking($this->salon, $customer, now()->subDays(3), BookingStatus::Completed);
    }

    public function test_salon_sees_its_bookings_with_customer_details(): void
    {
        $other = Salon::query()->create([
            'category_id' => $this->salon->category_id,
            'name' => 'صالون آخر',
            'phone' => '0199',
            'city' => 'الجيزة',
            'address' => 'شارع',
            'latitude' => 30,
            'longitude' => 31,
            'is_active' => true,
        ]);
        $this->booking($other, null, now()->addDay(), BookingStatus::Pending);

        $response = $this->withToken($this->token)->getJson('/api/salon/bookings')->assertOk();

        $response->assertJsonCount(2, 'data')
            ->assertJsonPath('salon.name', 'صالون الأناقة')
            ->assertJsonPath('data.0.id', $this->upcoming->id)
            ->assertJsonPath('data.0.can_confirm', true)
            ->assertJsonPath('data.0.can_cancel', true)
            ->assertJsonPath('data.0.notes', 'يفضل المقص')
            ->assertJsonPath('data.0.customer.phone', '0111')
            ->assertJsonPath('data.0.customer.email', 'client@test.local')
            ->assertJsonPath('data.0.customer.visits', 2)
            ->assertJsonPath('data.0.service.name', 'قص شعر')
            ->assertJsonPath('data.0.total', 150)
            ->assertJsonPath('data.1.can_confirm', false);
    }

    public function test_salon_confirms_then_cancels_with_a_reason(): void
    {
        $this->withToken($this->token)
            ->postJson("/api/salon/bookings/{$this->upcoming->id}/confirm")
            ->assertOk()
            ->assertJsonPath('data.status', 'confirmed')
            ->assertJsonPath('data.can_confirm', false);

        $this->withToken($this->token)
            ->postJson("/api/salon/bookings/{$this->upcoming->id}/confirm")
            ->assertStatus(422);

        $this->withToken($this->token)
            ->postJson("/api/salon/bookings/{$this->upcoming->id}/cancel", ['reason' => 'الأخصائي غير متاح'])
            ->assertOk()
            ->assertJsonPath('data.status', 'cancelled');

        $this->assertStringContainsString('الأخصائي غير متاح', $this->upcoming->fresh()->notes);
    }

    public function test_customers_and_other_salons_cannot_act(): void
    {
        $this->getJson('/api/salon/bookings')->assertStatus(401);

        $customer = User::query()->where('email', 'client@test.local')->first();
        $this->withToken($this->tokenFor($customer))->getJson('/api/salon/bookings')->assertStatus(403);

        $stranger = $this->user('other@test.local', '0122', UserRole::Salon);
        Salon::query()->create([
            'category_id' => $this->salon->category_id,
            'user_id' => $stranger->id,
            'name' => 'منافس',
            'phone' => '0122',
            'city' => 'القاهرة',
            'address' => 'شارع',
            'latitude' => 30,
            'longitude' => 31,
            'is_active' => true,
        ]);
        $this->withToken($this->tokenFor($stranger))
            ->postJson("/api/salon/bookings/{$this->upcoming->id}/cancel")
            ->assertStatus(404);

        $this->assertSame(BookingStatus::Pending, $this->upcoming->fresh()->status);
    }

    public function test_customer_books_with_cash_or_card(): void
    {
        foreach (range(0, 6) as $day) {
            $this->salon->workingHours()->create([
                'day_of_week' => $day,
                'opens_at' => '09:00',
                'closes_at' => '22:00',
                'is_closed' => false,
            ]);
        }
        $service = $this->salon->services()->first();
        $date = now()->addDays(2)->toDateString();
        $payload = [
            'service_id' => $service->id,
            'booked_on' => $date,
            'customer_name' => 'عميل',
            'customer_phone' => '0155',
        ];

        $this->postJson("/api/salons/{$this->salon->id}/bookings", $payload + ['booked_time' => '12:00'])
            ->assertCreated();
        $this->assertSame('cash', Booking::query()->latest('id')->value('payment_method'));

        $this->postJson("/api/salons/{$this->salon->id}/bookings", $payload + ['booked_time' => '13:00', 'payment_method' => 'card'])
            ->assertStatus(422)
            ->assertJsonValidationErrors('card_last4');

        $this->postJson("/api/salons/{$this->salon->id}/bookings", $payload + ['booked_time' => '13:00', 'payment_method' => 'card', 'card_last4' => '4242'])
            ->assertCreated();
        $card = Booking::query()->latest('id')->first();
        $this->assertSame('card', $card->payment_method);
        $this->assertSame('فيزا •••• 4242', $card->paymentLabel());

        $this->withToken($this->token)->getJson('/api/salon/bookings')
            ->assertJsonFragment(['payment_label' => 'فيزا •••• 4242']);
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

    private function booking(Salon $salon, ?User $customer, $at, BookingStatus $status, ?string $notes = null): Booking
    {
        $service = $salon->services()->firstOrCreate(['name' => 'قص شعر'], ['price' => 150, 'duration_minutes' => 30, 'is_active' => true]);
        $specialist = $salon->specialists()->firstOrCreate(['name' => 'أحمد'], ['title' => 'حلاق', 'is_active' => true]);

        return Booking::query()->create([
            'salon_id' => $salon->id,
            'service_id' => $service->id,
            'specialist_id' => $specialist->id,
            'user_id' => $customer?->id,
            'customer_name' => $customer?->name ?? 'زائر',
            'customer_phone' => $customer?->phone ?? '0199',
            'booked_on' => $at->toDateString(),
            'booked_time' => $at->format('H:i'),
            'status' => $status,
            'notes' => $notes,
        ]);
    }
}
