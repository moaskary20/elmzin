<?php

namespace Tests\Feature;

use App\Models\ShopCategory;
use App\Models\ShopOrder;
use App\Models\ShopProduct;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ShopOrderApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_guest_can_place_a_shop_order_and_stock_decreases(): void
    {
        $category = ShopCategory::query()->create([
            'name' => 'عناية الشعر',
            'slug' => 'hair-care',
            'is_active' => true,
            'sort_order' => 1,
        ]);

        $product = ShopProduct::query()->create([
            'shop_category_id' => $category->id,
            'name' => 'زيت أرغان',
            'description' => 'زيت مغذي',
            'price' => 100,
            'stock' => 10,
            'is_active' => true,
            'sort_order' => 1,
        ]);

        $response = $this->postJson('/api/shop/orders', [
            'customer_name' => 'محمد',
            'customer_phone' => '01000000000',
            'customer_address' => 'مدينة نصر',
            'payment_method' => 'cash',
            'items' => [
                ['product_id' => $product->id, 'quantity' => 2],
            ],
        ]);

        $response->assertCreated()
            ->assertJsonPath('data.total', 200)
            ->assertJsonPath('data.payment_method', 'cash');

        $this->assertDatabaseHas('shop_orders', [
            'customer_name' => 'محمد',
            'customer_phone' => '01000000000',
            'payment_method' => 'cash',
            'total' => 200,
        ]);

        $this->assertSame(8, $product->fresh()->stock);
        $this->assertSame(1, ShopOrder::query()->count());
    }

    public function test_order_rejects_quantity_above_stock(): void
    {
        $category = ShopCategory::query()->create([
            'name' => 'عناية الشعر',
            'slug' => 'hair-care-2',
            'is_active' => true,
            'sort_order' => 1,
        ]);

        $product = ShopProduct::query()->create([
            'shop_category_id' => $category->id,
            'name' => 'شامبو',
            'price' => 50,
            'stock' => 1,
            'is_active' => true,
            'sort_order' => 1,
        ]);

        $this->postJson('/api/shop/orders', [
            'customer_name' => 'محمد',
            'customer_phone' => '01000000000',
            'payment_method' => 'cash',
            'items' => [
                ['product_id' => $product->id, 'quantity' => 5],
            ],
        ])->assertStatus(422);
    }
}
