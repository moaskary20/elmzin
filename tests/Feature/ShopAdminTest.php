<?php

namespace Tests\Feature;

use App\Enums\ShopOrderStatus;
use App\Enums\UserRole;
use App\Filament\Resources\ShopCategories\Pages\ManageShopCategories;
use App\Filament\Resources\ShopOrders\Pages\ListShopOrders;
use App\Filament\Resources\ShopProducts\Pages\CreateShopProduct;
use App\Models\ShopCategory;
use App\Models\ShopOrder;
use App\Models\ShopOrderItem;
use App\Models\ShopProduct;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\TestCase;

class ShopAdminTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->actingAs(User::query()->create([
            'name' => 'مدير',
            'email' => 'shop-admin@test.local',
            'phone' => '01000009999',
            'password' => 'secret12',
            'role' => UserRole::Admin,
            'is_active' => true,
        ]));
    }

    public function test_admin_can_manage_shop_categories_products_and_see_orders(): void
    {
        Livewire::test(ManageShopCategories::class)
            ->callAction('create', [
                'name' => 'عناية شعر',
                'slug' => 'hair-care',
                'is_active' => true,
                'sort_order' => 0,
            ])
            ->assertHasNoActionErrors();

        $category = ShopCategory::query()->where('slug', 'hair-care')->firstOrFail();

        Livewire::test(CreateShopProduct::class)
            ->fillForm([
                'shop_category_id' => $category->id,
                'name' => 'زيت شعر',
                'price' => 150,
                'stock' => 20,
                'is_active' => true,
                'sort_order' => 0,
            ])
            ->call('create')
            ->assertHasNoFormErrors();

        $product = ShopProduct::query()->where('name', 'زيت شعر')->firstOrFail();
        $this->assertSame(150.0, (float) $product->price);

        $order = ShopOrder::query()->create([
            'customer_name' => 'أحمد',
            'customer_phone' => '01011112222',
            'customer_address' => 'القاهرة',
            'status' => ShopOrderStatus::Pending,
            'total' => 0,
        ]);

        ShopOrderItem::query()->create([
            'shop_order_id' => $order->id,
            'shop_product_id' => $product->id,
            'product_name' => $product->name,
            'price' => $product->price,
            'quantity' => 2,
        ]);

        $order->refresh();
        $this->assertSame(300.0, (float) $order->total);

        Livewire::test(ListShopOrders::class)
            ->assertCanSeeTableRecords([$order]);
    }
}
