<?php

namespace Database\Seeders;

use App\Models\ShopCategory;
use App\Models\ShopProduct;
use Illuminate\Database\Seeder;

class ShopDemoSeeder extends Seeder
{
    public function run(): void
    {
        $categories = [
            [
                'slug' => 'hair-care',
                'name' => 'عناية الشعر',
                'description' => 'زيوت، شامبو، وحلول للعناية بالشعر.',
                'sort_order' => 1,
                'products' => [
                    ['name' => 'زيت أرغان للشعر', 'description' => 'زيت مغذي للشعر الجاف والتالف.', 'price' => 180, 'compare_at_price' => 220, 'stock' => 40, 'image' => 'shop/products/argan-oil.jpg'],
                    ['name' => 'شامبو بروتين', 'description' => 'شامبو يقوّي الشعر ويقلل التساقط.', 'price' => 95, 'compare_at_price' => null, 'stock' => 60, 'image' => 'shop/products/protein-shampoo.jpg'],
                    ['name' => 'كريم تصفيف', 'description' => 'تثبيت خفيف مع لمعان طبيعي.', 'price' => 75, 'compare_at_price' => 90, 'stock' => 55, 'image' => 'shop/products/styling-cream.jpg'],
                ],
            ],
            [
                'slug' => 'skin-care',
                'name' => 'العناية بالبشرة',
                'description' => 'منتجات تنظيف وترطيب للبشرة.',
                'sort_order' => 2,
                'products' => [
                    ['name' => 'غسول وجه لطيف', 'description' => 'ينظف البشرة دون جفاف.', 'price' => 120, 'compare_at_price' => null, 'stock' => 45, 'image' => 'shop/products/face-wash.jpg'],
                    ['name' => 'ماسك فحم', 'description' => 'ينقي المسام ويقلل الرؤوس السوداء.', 'price' => 85, 'compare_at_price' => 110, 'stock' => 35, 'image' => 'shop/products/charcoal-mask.jpg'],
                    ['name' => 'كريم مرطب نهاري', 'description' => 'ترطيب يومي مناسب لكل أنواع البشرة.', 'price' => 160, 'compare_at_price' => null, 'stock' => 30, 'image' => 'shop/products/day-moisturizer.jpg'],
                ],
            ],
            [
                'slug' => 'beard-tools',
                'name' => 'مستلزمات اللحية',
                'description' => 'زيوت وأدوات للعناية باللحية.',
                'sort_order' => 3,
                'products' => [
                    ['name' => 'زيت لحية خشبي', 'description' => 'يليّن اللحية ويعطيها رائحة خفيفة.', 'price' => 110, 'compare_at_price' => 140, 'stock' => 50, 'image' => 'shop/products/beard-oil.jpg'],
                    ['name' => 'مشط لحية خشبي', 'description' => 'مشط مخصص لتسريح اللحية.', 'price' => 45, 'compare_at_price' => null, 'stock' => 80, 'image' => 'shop/products/beard-comb.jpg'],
                ],
            ],
            [
                'slug' => 'kids-fun',
                'name' => 'منتجات أطفال',
                'description' => 'منتجات لطيفة مناسبة لصالونات الأطفال.',
                'sort_order' => 4,
                'products' => [
                    ['name' => 'شامبو أطفال', 'description' => 'تركيبة لطيفة بدون دموع.', 'price' => 70, 'compare_at_price' => null, 'stock' => 70, 'image' => 'shop/products/kids-shampoo.jpg'],
                    ['name' => 'طلاء أظافر آمن', 'description' => 'ألوان مرحة قابلة للإزالة بسهولة.', 'price' => 55, 'compare_at_price' => 65, 'stock' => 90, 'image' => 'shop/products/kids-nail-polish.jpg'],
                ],
            ],
        ];

        foreach ($categories as $index => $row) {
            $category = ShopCategory::query()->updateOrCreate(
                ['slug' => $row['slug']],
                [
                    'name' => $row['name'],
                    'description' => $row['description'],
                    'sort_order' => $row['sort_order'],
                    'is_active' => true,
                ],
            );

            foreach ($row['products'] as $productIndex => $product) {
                ShopProduct::query()->updateOrCreate(
                    [
                        'shop_category_id' => $category->id,
                        'name' => $product['name'],
                    ],
                    [
                        'description' => $product['description'],
                        'price' => $product['price'],
                        'compare_at_price' => $product['compare_at_price'],
                        'stock' => $product['stock'],
                        'image' => $product['image'] ?? null,
                        'is_active' => true,
                        'sort_order' => $productIndex + 1,
                    ],
                );
            }
        }
    }
}
