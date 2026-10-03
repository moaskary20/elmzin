<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    private const SERVICES = [
        ['تريتمنت للشعر', 'علاج مكثف لترميم الشعر التالف وإعادة لمعانه.', 400, 60],
        ['تشقير للوجه', 'تفتيح شعر الوجه ليتناسق مع لون البشرة.', 100, 20],
        ['حمام مغربي', 'تقشير وتنظيف عميق للجسم بالصابون المغربي والكيس.', 500, 90],
        ['سويت لكامل الجسم', 'إزالة شعر الجسم بالكامل بالسكر الطبيعي.', 450, 90],
        ['حمامات بخار للوجه والشعر', 'جلسة بخار لفتح المسام وترطيب الشعر.', 150, 30],
        ['ميكروبليندنج للحواجب', 'رسم شعيرات الحواجب بشكل طبيعي شبه دائم.', 1500, 120],
    ];

    public function up(): void
    {
        $category = DB::table('categories')->where('slug', 'women')->value('id');

        if (! $category) {
            return;
        }

        $order = (int) DB::table('catalog_services')->where('category_id', $category)->max('sort_order');
        $now = now();

        foreach (self::SERVICES as [$name, $description, $price, $minutes]) {
            $exists = DB::table('catalog_services')
                ->where('category_id', $category)
                ->where('name', $name)
                ->exists();

            if ($exists) {
                continue;
            }

            DB::table('catalog_services')->insert([
                'category_id' => $category,
                'name' => $name,
                'description' => $description,
                'price' => $price,
                'duration_minutes' => $minutes,
                'sort_order' => ++$order,
                'is_active' => true,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }
    }

    public function down(): void
    {
        $category = DB::table('categories')->where('slug', 'women')->value('id');

        DB::table('catalog_services')
            ->where('category_id', $category)
            ->whereIn('name', array_column(self::SERVICES, 0))
            ->delete();
    }
};
