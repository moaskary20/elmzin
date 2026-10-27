<?php

namespace Tests\Feature;

use Database\Seeders\ShopDemoSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ShopCatalogApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_shop_catalog_returns_categories_and_products(): void
    {
        $this->seed(ShopDemoSeeder::class);

        $this->getJson('/api/shop/catalog')
            ->assertOk()
            ->assertJsonPath('data.0.name', 'عناية الشعر')
            ->assertJsonStructure([
                'data' => [
                    [
                        'id',
                        'name',
                        'slug',
                        'products' => [
                            ['id', 'name', 'price', 'stock', 'category'],
                        ],
                    ],
                ],
            ]);
    }
}
