<?php

namespace Tests\Feature;

use App\Enums\BookingStatus;
use App\Enums\UserRole;
use App\Models\Booking;
use App\Models\CatalogService;
use App\Models\Category;
use App\Models\Salon;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

class SalonProfileTest extends TestCase
{
    use RefreshDatabase;

    private string $token;

    private Salon $salon;

    private Category $men;

    protected function setUp(): void
    {
        parent::setUp();

        $this->men = Category::query()->create(['name' => 'رجالي', 'slug' => 'men', 'is_active' => true]);
        $owner = User::query()->create([
            'name' => 'owner',
            'email' => 'owner@test.local',
            'phone' => '0100',
            'password' => 'secret12',
            'role' => UserRole::Salon,
            'is_active' => true,
        ]);
        $raw = Str::random(60);
        $owner->forceFill(['api_token' => hash('sha256', $raw)])->save();
        $this->token = $raw;
        $this->salon = Salon::query()->create([
            'category_id' => $this->men->id,
            'user_id' => $owner->id,
            'name' => 'صالون قديم',
            'phone' => '0100',
            'city' => 'القاهرة',
            'address' => 'شارع',
            'latitude' => 30,
            'longitude' => 31,
            'is_active' => true,
        ]);
    }

    public function test_salon_edits_its_details_and_hours(): void
    {
        $this->getJson('/api/salon/profile')->assertStatus(401);

        $this->withToken($this->token)->getJson('/api/salon/profile')
            ->assertOk()
            ->assertJsonPath('data.name', 'صالون قديم')
            ->assertJsonCount(7, 'data.hours')
            ->assertJsonPath('data.hours.0.label', 'السبت')
            ->assertJsonPath('data.hours.0.is_closed', true);

        $this->withToken($this->token)->patchJson('/api/salon/profile', [
            'name' => 'صالون جديد',
            'about' => 'نبذة',
            'district' => 'المعادي',
            'offers_home_service' => true,
        ])->assertOk()
            ->assertJsonPath('data.name', 'صالون جديد')
            ->assertJsonPath('data.district', 'المعادي')
            ->assertJsonPath('data.offers_home_service', true);

        $this->withToken($this->token)->patchJson('/api/salon/profile', ['name' => ''])
            ->assertStatus(422);

        $hours = collect([6, 0, 1, 2, 3, 4, 5])->map(fn (int $day): array => [
            'day' => $day,
            'is_closed' => $day === 5,
            'opens_at' => $day === 5 ? null : '10:00',
            'closes_at' => $day === 5 ? null : '22:00',
        ])->all();

        $this->withToken($this->token)->putJson('/api/salon/hours', ['hours' => $hours])
            ->assertOk()
            ->assertJsonPath('data.hours.0.opens_at', '10:00')
            ->assertJsonPath('data.hours.6.is_closed', true);

        $hours[0]['closes_at'] = '09:00';
        $this->withToken($this->token)->putJson('/api/salon/hours', ['hours' => $hours])
            ->assertStatus(422);
    }

    public function test_salon_manages_services_and_specialists(): void
    {
        $cut = CatalogService::query()->create(['category_id' => $this->men->id, 'name' => 'قص شعر', 'duration_minutes' => 40, 'is_active' => true]);
        $women = Category::query()->create(['name' => 'حريمي', 'slug' => 'women', 'is_active' => true]);
        $makeup = CatalogService::query()->create(['category_id' => $women->id, 'name' => 'مكياج', 'is_active' => true]);

        $this->withToken($this->token)->getJson('/api/salon/profile')
            ->assertJsonPath('catalog.0.name', 'قص شعر')
            ->assertJsonCount(1, 'catalog');

        $this->withToken($this->token)->postJson('/api/salon/services', ['catalog_service_id' => $makeup->id, 'price' => 100])
            ->assertStatus(422);

        $response = $this->withToken($this->token)->postJson('/api/salon/services', ['catalog_service_id' => $cut->id, 'price' => 150])
            ->assertCreated()
            ->assertJsonPath('data.services.0.name', 'قص شعر')
            ->assertJsonPath('data.services.0.price', 150)
            ->assertJsonPath('data.services.0.duration_minutes', 40)
            ->assertJsonCount(0, 'catalog');
        $serviceId = $response->json('data.services.0.id');

        $this->withToken($this->token)->postJson('/api/salon/services', ['catalog_service_id' => $cut->id, 'price' => 150])
            ->assertStatus(422);

        $specialistId = $this->withToken($this->token)->postJson('/api/salon/specialists', ['name' => 'أحمد', 'title' => 'حلاق'])
            ->assertCreated()
            ->json('data.specialists.0.id');

        $this->withToken($this->token)->patchJson("/api/salon/services/{$serviceId}", [
            'price' => 175,
            'is_active' => false,
            'specialist_ids' => [$specialistId],
        ])->assertOk()
            ->assertJsonPath('data.services.0.price', 175)
            ->assertJsonPath('data.services.0.is_active', false)
            ->assertJsonPath('data.services.0.specialist_ids.0', $specialistId);

        $this->withToken($this->token)->patchJson("/api/salon/specialists/{$specialistId}", ['is_active' => false])
            ->assertOk()
            ->assertJsonPath('data.specialists.0.is_active', false);

        Booking::query()->create([
            'salon_id' => $this->salon->id,
            'service_id' => $serviceId,
            'specialist_id' => $specialistId,
            'customer_name' => 'عميل',
            'customer_phone' => '0111',
            'booked_on' => now()->addDay()->toDateString(),
            'booked_time' => '12:00',
            'status' => BookingStatus::Pending,
        ]);

        $this->withToken($this->token)->deleteJson("/api/salon/services/{$serviceId}")->assertStatus(422);
        $this->withToken($this->token)->deleteJson("/api/salon/specialists/{$specialistId}")->assertStatus(422);
        $this->assertDatabaseCount('bookings', 1);

        $spare = $this->withToken($this->token)->postJson('/api/salon/specialists', ['name' => 'محمود'])->json('data.specialists');
        $spareId = collect($spare)->firstWhere('name', 'محمود')['id'];
        $this->withToken($this->token)->deleteJson("/api/salon/specialists/{$spareId}")
            ->assertOk()
            ->assertJsonCount(1, 'data.specialists');
    }

    public function test_salon_cannot_touch_another_salons_records(): void
    {
        $other = Salon::query()->create([
            'category_id' => $this->men->id,
            'name' => 'منافس',
            'phone' => '0199',
            'city' => 'القاهرة',
            'address' => 'شارع',
            'latitude' => 30,
            'longitude' => 31,
            'is_active' => true,
        ]);
        $service = $other->services()->create(['name' => 'قص', 'price' => 50, 'duration_minutes' => 30, 'is_active' => true]);
        $specialist = $other->specialists()->create(['name' => 'غريب', 'is_active' => true]);

        $this->withToken($this->token)->patchJson("/api/salon/services/{$service->id}", ['price' => 1])->assertNotFound();
        $this->withToken($this->token)->deleteJson("/api/salon/services/{$service->id}")->assertNotFound();
        $this->withToken($this->token)->deleteJson("/api/salon/specialists/{$specialist->id}")->assertNotFound();
        $this->assertSame('50.00', $service->fresh()->price);
    }
}
