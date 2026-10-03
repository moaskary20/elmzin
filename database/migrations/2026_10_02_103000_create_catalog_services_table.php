<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('catalog_services', function (Blueprint $table) {
            $table->id();
            $table->foreignId('category_id')->constrained()->cascadeOnDelete();
            $table->string('name');
            $table->string('description')->nullable();
            $table->decimal('price', 10, 2)->default(0);
            $table->unsignedInteger('duration_minutes')->default(30);
            $table->unsignedInteger('sort_order')->default(0);
            $table->boolean('is_active')->default(true);
            $table->timestamps();

            $table->unique(['category_id', 'name']);
        });

        $now = now();

        foreach ($this->catalog() as $slug => $services) {
            $categoryId = DB::table('categories')->where('slug', $slug)->value('id');

            if (! $categoryId) {
                continue;
            }

            foreach ($services as $index => [$name, $price, $minutes, $description]) {
                DB::table('catalog_services')->insert([
                    'category_id' => $categoryId,
                    'name' => $name,
                    'description' => $description,
                    'price' => $price,
                    'duration_minutes' => $minutes,
                    'sort_order' => $index,
                    'is_active' => true,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('catalog_services');
    }

    private function catalog(): array
    {
        return [
            'men' => [
                ['قص شعر', 80, 30, 'قصة حسب الطلب مع غسيل وتصفيف.'],
                ['تهذيب لحية', 50, 20, 'تحديد وتهذيب اللحية بالماكينة والموس.'],
                ['حلاقة كاملة', 120, 45, 'قص الشعر مع تهذيب اللحية.'],
                ['حلاقة ذقن بالموس', 40, 15, 'حلاقة ناعمة بالموس مع فوطة ساخنة.'],
                ['سشوار وتصفيف', 60, 20, 'تصفيف الشعر بالسشوار والمنتجات.'],
                ['صبغة شعر', 150, 45, 'صبغة كاملة أو تغطية الشيب.'],
                ['صبغة لحية', 70, 20, 'تغطية الشيب في اللحية.'],
                ['تنظيف بشرة', 200, 45, 'تنظيف عميق للبشرة مع ماسك.'],
                ['ماسك الفحم', 70, 20, 'إزالة الرؤوس السوداء.'],
                ['حمام زيت', 100, 30, 'ترطيب وتغذية الشعر.'],
                ['بروتين وكيراتين', 450, 120, 'فرد وعلاج الشعر.'],
                ['إزالة الشعر بالخيط', 40, 15, 'تنظيف الوجه بالخيط.'],
                ['باكيج العريس', 900, 180, 'حلاقة كاملة وتنظيف بشرة وحمام زيت وتصفيف.'],
            ],
            'women' => [
                ['قص وتصفيف', 150, 45, 'قصة حسب الطلب مع سشوار.'],
                ['سشوار', 120, 40, 'تصفيف الشعر بالسشوار أو الويفي.'],
                ['صبغة شعر', 350, 90, 'صبغة كاملة بلون واحد.'],
                ['هايلايت', 500, 120, 'خصلات هايلايت أو لولايت.'],
                ['بروتين وكيراتين', 900, 150, 'فرد وعلاج الشعر.'],
                ['حمام كريم', 150, 40, 'ترطيب وتغذية الشعر.'],
                ['تسريحة مناسبات', 300, 60, 'تسريحة للسهرات والمناسبات.'],
                ['مكياج سهرة', 400, 60, 'مكياج كامل للمناسبات.'],
                ['مكياج عروس', 1500, 150, 'مكياج العروس مع الرموش.'],
                ['عناية بشرة', 300, 60, 'تنظيف بشرة عميق مع ماسك.'],
                ['مانيكير', 120, 40, 'عناية الأظافر وطلاء.'],
                ['باديكير', 150, 45, 'عناية القدمين والأظافر.'],
                ['رسم حواجب وخيط', 60, 20, 'تحديد الحواجب وتنظيف الوجه.'],
                ['تركيب رموش', 250, 60, 'رموش طبيعية أو كثيفة.'],
                ['حنة', 200, 60, 'نقش حنة لليدين والقدمين.'],
                ['باكيج العروس', 3000, 300, 'شعر ومكياج وعناية بشرة ومانيكير وباديكير.'],
            ],
            'kids' => [
                ['قصة أطفال', 60, 20, 'قصة هادئة للأطفال.'],
                ['قصة أول مرة', 70, 25, 'أول قصة مع صورة تذكارية.'],
                ['رسمات شعر', 80, 30, 'رسومات وخطوط بالماكينة.'],
                ['تسريحة بنات', 100, 30, 'تسريحة بسيطة للبنات.'],
                ['ضفائر', 120, 45, 'ضفائر وجدائل بأشكال مختلفة.'],
                ['تسريحة حفلات', 150, 45, 'تسريحة لأعياد الميلاد والحفلات.'],
                ['رسم على الوجه', 50, 20, 'رسومات ملونة آمنة.'],
                ['مانيكير أطفال', 60, 20, 'طلاء أظافر آمن للأطفال.'],
            ],
        ];
    }
};
