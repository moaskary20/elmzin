<?php

namespace Tests\Feature;

use App\Enums\UserRole;
use App\Filament\Resources\CatalogServices\Pages\ManageCatalogServices;
use App\Filament\Resources\Salons\Pages\EditSalon;
use App\Filament\Resources\Salons\RelationManagers\ServicesRelationManager;
use App\Models\CatalogService;
use App\Models\Category;
use App\Models\Salon;
use App\Models\User;
use Filament\Actions\Testing\TestAction;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\TestCase;

class CatalogServicesTest extends TestCase
{
    use RefreshDatabase;

    private Category $men;

    private Category $women;

    protected function setUp(): void
    {
        parent::setUp();

        $this->actingAs(User::query()->create([
            'name' => 'مدير',
            'email' => 'admin@test.local',
            'phone' => '0100000000',
            'password' => 'secret12',
            'role' => UserRole::Admin,
            'is_active' => true,
        ]));

        $this->men = Category::query()->create(['name' => 'رجالي', 'slug' => 'men', 'is_active' => true]);
        $this->women = Category::query()->create(['name' => 'حريمي', 'slug' => 'women', 'is_active' => true]);
    }

    public function test_admin_adds_a_catalog_service_with_only_name_and_category(): void
    {
        Livewire::test(ManageCatalogServices::class)
            ->callAction('create', ['category_id' => $this->men->id, 'name' => 'قص أطراف', 'is_active' => true])
            ->assertHasNoActionErrors();

        $this->assertDatabaseHas('catalog_services', ['category_id' => $this->men->id, 'name' => 'قص أطراف']);

        Livewire::test(ManageCatalogServices::class)
            ->callAction('create', ['category_id' => $this->men->id, 'name' => 'قص أطراف', 'is_active' => true])
            ->assertHasActionErrors(['name' => 'unique']);

        Livewire::test(ManageCatalogServices::class)
            ->callAction('create', ['category_id' => $this->women->id, 'name' => 'قص أطراف', 'is_active' => true])
            ->assertHasNoActionErrors();
    }

    public function test_salon_adds_a_service_from_its_category_with_a_price(): void
    {
        $cut = CatalogService::query()->create(['category_id' => $this->men->id, 'name' => 'قص شعر', 'duration_minutes' => 45]);
        $beard = CatalogService::query()->create(['category_id' => $this->men->id, 'name' => 'تهذيب لحية']);
        $makeup = CatalogService::query()->create(['category_id' => $this->women->id, 'name' => 'مكياج']);
        $salon = Salon::query()->create([
            'category_id' => $this->men->id,
            'name' => 'صالون تجربة',
            'phone' => '0101',
            'city' => 'القاهرة',
            'address' => 'شارع',
            'latitude' => 30,
            'longitude' => 31,
            'is_active' => true,
        ]);
        $salon->services()->create(['catalog_service_id' => $beard->id, 'name' => $beard->name, 'price' => 50, 'duration_minutes' => 20]);

        $component = Livewire::test(ServicesRelationManager::class, [
            'ownerRecord' => $salon,
            'pageClass' => EditSalon::class,
        ]);

        $component->mountAction(TestAction::make('create')->table())
            ->assertFormFieldExists('catalog_service_id', function ($field) use ($cut, $beard, $makeup): bool {
                $options = $field->getOptions();

                return isset($options[$cut->id]) && ! isset($options[$beard->id]) && ! isset($options[$makeup->id]);
            });

        Livewire::test(ServicesRelationManager::class, ['ownerRecord' => $salon, 'pageClass' => EditSalon::class])
            ->callAction(TestAction::make('create')->table(), [
                'catalog_service_id' => $cut->id,
                'price' => 140,
                'duration_minutes' => 45,
                'is_active' => true,
            ])
            ->assertHasNoActionErrors();

        $this->assertDatabaseHas('services', [
            'salon_id' => $salon->id,
            'catalog_service_id' => $cut->id,
            'name' => 'قص شعر',
            'price' => 140,
        ]);

        $cut->update(['name' => 'قص شعر احترافي']);
        $this->assertDatabaseHas('services', ['catalog_service_id' => $cut->id, 'name' => 'قص شعر احترافي']);
    }

    public function test_salon_signup_sets_a_price_for_each_chosen_service(): void
    {
        $cut = CatalogService::query()->create(['category_id' => $this->men->id, 'name' => 'قص شعر', 'price' => 0]);

        $payload = [
            'account_type' => 'salon',
            'name' => 'صالون جديد',
            'email' => 'salon@test.local',
            'phone' => '0102',
            'password' => 'secret12',
            'address' => 'شارع',
            'latitude' => 30,
            'longitude' => 31,
            'category_id' => $this->men->id,
        ];

        $this->postJson('/api/auth/register', $payload + ['services' => [['id' => $cut->id]]])
            ->assertStatus(422)
            ->assertJsonValidationErrors('services.0.price');

        $this->postJson('/api/auth/register', $payload + ['services' => [['id' => $cut->id, 'price' => 95]]])
            ->assertCreated();

        $this->assertDatabaseHas('services', ['catalog_service_id' => $cut->id, 'price' => 95]);
        $this->getJson('/api/catalog')->assertOk()->assertJsonMissingPath('data.0.services.0.price');
    }
}
