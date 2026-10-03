<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('subscription_plans', function (Blueprint $table): void {
            $table->id();
            $table->string('name');
            $table->string('tagline')->nullable();
            $table->string('badge', 60)->nullable();
            $table->decimal('price', 10, 2)->default(0);
            $table->unsignedInteger('duration_value')->default(1);
            $table->string('duration_unit', 10)->default('year');
            $table->json('features')->nullable();
            $table->text('terms')->nullable();
            $table->unsignedInteger('max_services')->nullable();
            $table->unsignedInteger('max_specialists')->nullable();
            $table->boolean('is_featured')->default(false);
            $table->boolean('is_active')->default(true);
            $table->unsignedInteger('sort_order')->default(0);
            $table->timestamps();
        });

        Schema::create('salon_subscriptions', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('salon_id')->constrained()->cascadeOnDelete();
            $table->foreignId('subscription_plan_id')->nullable()->constrained()->nullOnDelete();
            $table->string('plan_name');
            $table->decimal('price', 10, 2)->default(0);
            $table->dateTime('starts_at');
            $table->dateTime('ends_at');
            $table->string('status', 20)->default('active');
            $table->timestamp('terms_accepted_at')->nullable();
            $table->text('notes')->nullable();
            $table->timestamps();
            $table->index(['salon_id', 'status', 'ends_at']);
        });

        DB::table('subscription_plans')->insert([
            'name' => 'باقة الانطلاق',
            'tagline' => 'اشتراك مجاني لمدة سنة كاملة',
            'badge' => 'مجاناً لمدة سنة',
            'price' => 0,
            'duration_value' => 1,
            'duration_unit' => 'year',
            'features' => json_encode([
                'ظهور صالونك لكل عملاء المزين في منطقتك',
                'استقبال الحجوزات وإدارتها من التطبيق',
                'إضافة الخدمات والأسعار والأخصائيين بلا حدود',
                'إشعارات فورية بكل حجز وتقييم جديد',
                'تقييمات العملاء وصفحة خاصة لصالونك',
            ], JSON_UNESCAPED_UNICODE),
            'terms' => implode("\n", [
                'الاشتراك مجاني بالكامل لمدة سنة من تاريخ التسجيل، ولا تُطلب أي بيانات دفع.',
                'يجب أن تكون بيانات الصالون وصوره وأسعاره صحيحة ومحدّثة.',
                'يلتزم الصالون بتأكيد الحجوزات أو إلغائها في الوقت المناسب واحترام مواعيد العملاء.',
                'يحق لإدارة المزين إيقاف الحساب عند مخالفة الشروط أو تكرار شكاوى العملاء.',
                'عند انتهاء السنة المجانية يمكن الانتقال إلى إحدى الباقات المدفوعة دون فقدان بياناتك.',
            ]),
            'max_services' => null,
            'max_specialists' => null,
            'is_featured' => true,
            'is_active' => true,
            'sort_order' => 1,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    public function down(): void
    {
        Schema::dropIfExists('salon_subscriptions');
        Schema::dropIfExists('subscription_plans');
    }
};
