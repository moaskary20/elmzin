<?php

namespace Tests\Feature;

use App\Enums\UserRole;
use App\Filament\Resources\SubscriptionPlans\Pages\CreateSubscriptionPlan;
use App\Filament\Resources\SubscriptionPlans\Pages\ListSubscriptionPlans;
use App\Models\AppNotification;
use App\Models\CatalogService;
use App\Models\Category;
use App\Models\Salon;
use App\Models\SalonSubscription;
use App\Models\SubscriptionPlan;
use App\Models\User;
use App\Services\SubscriptionService;
use Filament\Forms\Components\Repeater;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Livewire\Livewire;
use Tests\TestCase;

class SubscriptionPlansTest extends TestCase
{
    use RefreshDatabase;

    private Category $men;

    protected function setUp(): void
    {
        parent::setUp();

        $this->men = Category::query()->create(['name' => 'رجالي', 'slug' => 'men', 'is_active' => true]);
    }

    public function test_the_first_plan_is_a_free_year_and_is_listed_for_the_app(): void
    {
        SubscriptionPlan::query()->create([
            'name' => 'مخفية',
            'price' => 500,
            'duration_value' => 6,
            'duration_unit' => 'month',
            'is_active' => false,
            'sort_order' => 0,
        ]);

        $this->getJson('/api/subscription-plans')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.name', 'باقة الانطلاق')
            ->assertJsonPath('data.0.is_free', true)
            ->assertJsonPath('data.0.price_label', 'مجاناً')
            ->assertJsonPath('data.0.duration_label', 'سنة واحدة')
            ->assertJsonPath('data.0.badge', 'مجاناً لمدة سنة')
            ->assertJsonPath('data.0.image_url', null)
            ->assertJsonCount(5, 'data.0.features')
            ->assertJsonCount(5, 'data.0.terms');
    }

    public function test_plan_image_is_exposed_through_the_api(): void
    {
        $path = 'subscription-plans/test-plan.png';
        \Illuminate\Support\Facades\Storage::fake('public');
        \Illuminate\Support\Facades\Storage::disk('public')->put($path, 'fake-image');

        $plan = SubscriptionPlan::query()->available()->firstOrFail();
        $plan->update(['image' => $path]);

        $this->getJson('/api/subscription-plans')
            ->assertOk()
            ->assertJsonPath('data.0.image_url', url('/api/subscription-plans/'.$plan->id.'/image'));

        $this->get('/api/subscription-plans/'.$plan->id.'/image')->assertOk();
    }

    public function test_salon_signup_subscribes_to_the_chosen_plan_after_accepting_terms(): void
    {
        $cut = CatalogService::query()->create(['category_id' => $this->men->id, 'name' => 'قص شعر', 'price' => 0]);
        $plan = SubscriptionPlan::query()->available()->first();
        $payload = $this->signup($cut) + ['plan_id' => $plan->id];

        $this->postJson('/api/auth/register', $payload)
            ->assertStatus(422)
            ->assertJsonValidationErrors('accept_terms');

        $response = $this->postJson('/api/auth/register', $payload + ['accept_terms' => true])->assertCreated();

        $salon = Salon::query()->where('name', 'صالون جديد')->firstOrFail();
        $subscription = $salon->currentSubscription()->first();
        $this->assertSame('باقة الانطلاق', $subscription->plan_name);
        $this->assertSame(0.0, (float) $subscription->price);
        $this->assertNotNull($subscription->terms_accepted_at);
        $this->assertTrue($subscription->ends_at->isSameDay(now()->addYear()));

        $owner = $salon->owner;
        $this->assertTrue(AppNotification::query()->where('user_id', $owner->id)->where('type', 'subscription')->exists());

        $this->withToken($response->json('token'))->getJson('/api/salon/profile')
            ->assertOk()
            ->assertJsonPath('subscription.plan_name', 'باقة الانطلاق')
            ->assertJsonPath('subscription.is_free', true)
            ->assertJsonPath('subscription.status', 'active');
    }

    public function test_plan_limits_apply_to_signup_and_salon_management(): void
    {
        $cut = CatalogService::query()->create(['category_id' => $this->men->id, 'name' => 'قص شعر', 'price' => 0]);
        $beard = CatalogService::query()->create(['category_id' => $this->men->id, 'name' => 'لحية', 'price' => 0]);
        $basic = SubscriptionPlan::query()->create([
            'name' => 'أساسية',
            'price' => 199,
            'duration_value' => 1,
            'duration_unit' => 'month',
            'max_services' => 1,
            'max_specialists' => 1,
            'is_active' => true,
            'sort_order' => 5,
        ]);

        $payload = $this->signup($cut) + ['plan_id' => $basic->id, 'accept_terms' => true];
        $payload['services'][] = ['id' => $beard->id, 'price' => 50];
        $this->postJson('/api/auth/register', $payload)
            ->assertStatus(422)
            ->assertJsonValidationErrors('services');

        $payload['services'] = [['id' => $cut->id, 'price' => 90]];
        $token = $this->postJson('/api/auth/register', $payload)->assertCreated()->json('token');

        $this->withToken($token)->postJson('/api/salon/services', ['catalog_service_id' => $beard->id, 'price' => 50])
            ->assertStatus(422)
            ->assertJsonValidationErrors('catalog_service_id');

        $this->withToken($token)->postJson('/api/salon/specialists', ['name' => 'أحمد', 'title' => 'حلاق'])->assertCreated();
        $this->withToken($token)->postJson('/api/salon/specialists', ['name' => 'محمود', 'title' => 'حلاق'])
            ->assertStatus(422);

        $salon = Salon::query()->where('name', 'صالون جديد')->firstOrFail();
        $this->assertTrue($salon->currentSubscription->ends_at->isSameDay(now()->addMonth()));

        $next = app(SubscriptionService::class)->renew($salon, SubscriptionPlan::query()->first());
        $this->assertTrue($next->starts_at->isSameDay(now()->addMonth()));
        $this->assertTrue($next->ends_at->isSameDay(now()->addMonth()->addYear()));
    }

    public function test_admin_manages_plans(): void
    {
        $this->actingAs(User::query()->create([
            'name' => 'مدير',
            'email' => 'admin@test.local',
            'phone' => '0100000000',
            'password' => 'secret12',
            'role' => UserRole::Admin,
            'is_active' => true,
        ]));

        $this->get('/admin/subscription-plans')->assertOk()->assertSee('باقة الانطلاق');
        $this->get('/admin/salon-subscriptions')->assertOk();

        $undo = Repeater::fake();

        Livewire::test(CreateSubscriptionPlan::class)
            ->fillForm([
                'name' => 'الباقة الاحترافية',
                'badge' => 'الأكثر طلباً',
                'pricing_type' => 'fixed',
                'price' => 1200,
                'duration_value' => 1,
                'duration_unit' => 'year',
                'features' => [['text' => 'ظهور مميز في الرئيسية'], ['text' => 'دعم فني مخصص']],
                'terms' => "بند أول\nبند ثانٍ",
                'max_services' => 30,
            ])
            ->call('create')
            ->assertHasNoFormErrors();

        $undo();

        $plan = SubscriptionPlan::query()->where('name', 'الباقة الاحترافية')->firstOrFail();
        $this->assertSame(['ظهور مميز في الرئيسية', 'دعم فني مخصص'], $plan->features);
        $this->assertSame('1,200 ج.م', $plan->priceLabel());

        Livewire::test(ListSubscriptionPlans::class)->assertCanSeeTableRecords([$plan]);
        $this->assertSame(0, SalonSubscription::query()->count());
    }

    public function test_percentage_plan_is_listed_and_applied_on_signup(): void
    {
        $cut = CatalogService::query()->create(['category_id' => $this->men->id, 'name' => 'قص شعر', 'price' => 0]);
        $plan = SubscriptionPlan::query()->create([
            'name' => 'باقة الشراكة',
            'name_en' => 'Partnership',
            'pricing_type' => 'percentage',
            'commission_percent' => 15,
            'price' => 999,
            'duration_value' => 1,
            'duration_unit' => 'year',
            'features' => ['نسبة مرنة'],
            'terms' => "يُحتسب العمولة من كل حجز",
            'is_active' => true,
            'sort_order' => 20,
        ]);

        $this->assertSame(0.0, (float) $plan->fresh()->price);
        $this->assertTrue($plan->fresh()->isPercentage());
        $this->assertSame('عمولة 15% للتطبيق', $plan->fresh()->priceLabel());
        $this->assertSame('15% app share', $plan->fresh()->priceLabel(true));

        $this->getJson('/api/subscription-plans')
            ->assertOk()
            ->assertJsonFragment([
                'id' => $plan->id,
                'pricing_type' => 'percentage',
                'commission_percent' => 15,
                'is_percentage' => true,
                'is_free' => false,
                'price_label' => 'عمولة 15% للتطبيق',
            ]);

        $token = $this->postJson('/api/auth/register', $this->signup($cut) + [
            'plan_id' => $plan->id,
            'accept_terms' => true,
        ])->assertCreated()->json('token');

        $salon = Salon::query()->where('name', 'صالون جديد')->firstOrFail();
        $subscription = $salon->currentSubscription()->first();
        $this->assertSame('percentage', $subscription->pricing_type);
        $this->assertSame(15.0, (float) $subscription->commission_percent);
        $this->assertSame(0.0, (float) $subscription->price);

        $this->withToken($token)->getJson('/api/salon/profile')
            ->assertOk()
            ->assertJsonPath('subscription.pricing_type', 'percentage')
            ->assertJsonPath('subscription.commission_percent', 15)
            ->assertJsonPath('subscription.is_percentage', true)
            ->assertJsonPath('subscription.is_free', false);
    }

    private function signup(CatalogService $service): array
    {
        return [
            'account_type' => 'salon',
            'name' => 'صالون جديد',
            'email' => Str::random(6).'@test.local',
            'phone' => '01'.random_int(10000000, 99999999),
            'password' => 'secret12',
            'address' => 'شارع',
            'latitude' => 30,
            'longitude' => 31,
            'category_id' => $this->men->id,
            'national_id' => '29501011234567',
            'services' => [['id' => $service->id, 'price' => 95]],
        ];
    }
}
