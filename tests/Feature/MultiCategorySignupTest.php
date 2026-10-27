<?php

namespace Tests\Feature;

use App\Models\CatalogService;
use App\Models\Category;
use App\Models\Salon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class MultiCategorySignupTest extends TestCase
{
    use RefreshDatabase;

    public function test_salon_can_register_with_multiple_categories_and_their_services(): void
    {
        $men = Category::query()->create(['name' => 'رجالي', 'slug' => 'men', 'is_active' => true]);
        $women = Category::query()->create(['name' => 'حريمي', 'slug' => 'women', 'is_active' => true]);
        $cut = CatalogService::query()->create(['category_id' => $men->id, 'name' => 'قص شعر', 'price' => 0, 'is_active' => true]);
        $makeup = CatalogService::query()->create(['category_id' => $women->id, 'name' => 'مكياج', 'price' => 0, 'is_active' => true]);

        $response = $this->postJson('/api/auth/register', [
            'account_type' => 'salon',
            'name' => 'صالون متعدد',
            'email' => 'multi@test.local',
            'phone' => '01099990001',
            'password' => 'secret12',
            'address' => 'شارع',
            'latitude' => 30.1,
            'longitude' => 31.2,
            'category_ids' => [$men->id, $women->id],
            'national_id' => '29501011234567',
            'services' => [
                ['id' => $cut->id, 'price' => 90],
                ['id' => $makeup->id, 'price' => 200],
            ],
        ])->assertCreated();

        $salon = Salon::query()->where('name', 'صالون متعدد')->firstOrFail();
        $this->assertSame($men->id, $salon->category_id);
        $this->assertEqualsCanonicalizing([$men->id, $women->id], $salon->categories()->pluck('categories.id')->all());
        $this->assertDatabaseHas('services', ['salon_id' => $salon->id, 'catalog_service_id' => $cut->id, 'price' => 90]);
        $this->assertDatabaseHas('services', ['salon_id' => $salon->id, 'catalog_service_id' => $makeup->id, 'price' => 200]);

        $listed = collect($this->getJson('/api/salons')->assertOk()->json('data'))
            ->firstWhere('id', $salon->id);
        $this->assertNotNull($listed);
        $this->assertSame('men', $listed['category_slug']);
        $this->assertEqualsCanonicalizing(['men', 'women'], $listed['category_slugs']);

        $this->assertNotEmpty($response->json('token'));
    }
}
