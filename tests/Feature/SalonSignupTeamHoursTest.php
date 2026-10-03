<?php

namespace Tests\Feature;

use App\Models\CatalogService;
use App\Models\Category;
use App\Models\Salon;
use App\Models\SubscriptionPlan;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

class SalonSignupTeamHoursTest extends TestCase
{
    use RefreshDatabase;

    private Category $men;

    private CatalogService $cut;

    protected function setUp(): void
    {
        parent::setUp();

        $this->men = Category::query()->create(['name' => 'رجالي', 'slug' => 'men', 'is_active' => true]);
        $this->cut = CatalogService::query()->create(['category_id' => $this->men->id, 'name' => 'قص شعر', 'price' => 0]);
    }

    public function test_salon_signup_saves_specialists_and_working_hours(): void
    {
        $response = $this->postJson('/api/auth/register', $this->signup() + [
            'specialists' => [
                ['name' => 'كريم', 'title' => 'حلاق أول', 'phone' => '0100'],
                ['name' => 'يوسف'],
            ],
            'hours' => $this->hours(),
        ])->assertCreated();

        $salon = Salon::query()->where('name', 'صالون الفريق')->firstOrFail();
        $this->assertSame(['كريم', 'يوسف'], $salon->specialists()->orderBy('id')->pluck('name')->all());
        $this->assertSame('حلاق أول', $salon->specialists()->first()->title);
        $service = $salon->services()->first();
        $this->assertSame(2, $service->specialists()->count());

        $profile = $this->withToken($response->json('token'))->getJson('/api/salon/profile')->assertOk();
        $hours = collect($profile->json('data.hours'))->keyBy('day');
        $this->assertTrue($hours[5]['is_closed']);
        $this->assertSame('10:00', $hours[6]['opens_at']);
        $this->assertSame('22:00', $hours[6]['closes_at']);
    }

    public function test_salon_signup_rejects_bad_hours_and_too_many_specialists(): void
    {
        $hours = $this->hours();
        $hours[0]['closes_at'] = '09:00';

        $this->postJson('/api/auth/register', $this->signup() + ['hours' => $hours])
            ->assertStatus(422)
            ->assertJsonValidationErrors('hours');

        $plan = SubscriptionPlan::query()->available()->first();
        $plan->update(['max_specialists' => 1]);

        $this->postJson('/api/auth/register', $this->signup() + [
            'plan_id' => $plan->id,
            'accept_terms' => true,
            'specialists' => [['name' => 'أ'], ['name' => 'ب']],
        ])->assertStatus(422)->assertJsonValidationErrors('specialists');

        $this->assertSame(0, Salon::query()->count());
    }

    private function hours(): array
    {
        return collect([6, 0, 1, 2, 3, 4, 5])->map(fn (int $day): array => [
            'day' => $day,
            'is_closed' => $day === 5,
            'opens_at' => $day === 5 ? null : '10:00',
            'closes_at' => $day === 5 ? null : '22:00',
        ])->all();
    }

    private function signup(): array
    {
        return [
            'account_type' => 'salon',
            'name' => 'صالون الفريق',
            'email' => Str::random(6).'@test.local',
            'phone' => '01'.random_int(10000000, 99999999),
            'password' => 'secret12',
            'address' => 'شارع',
            'latitude' => 30,
            'longitude' => 31,
            'category_id' => $this->men->id,
            'services' => [['id' => $this->cut->id, 'price' => 95]],
        ];
    }
}
