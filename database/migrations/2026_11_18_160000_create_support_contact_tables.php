<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('support_options', function (Blueprint $table): void {
            $table->id();
            $table->string('field', 30); // topic | related
            $table->string('label');
            $table->string('label_en')->nullable();
            $table->boolean('is_other')->default(false);
            $table->boolean('is_active')->default(true);
            $table->unsignedInteger('sort_order')->default(0);
            $table->timestamps();

            $table->index(['field', 'is_active', 'sort_order']);
        });

        Schema::create('support_tickets', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('topic_option_id')->nullable()->constrained('support_options')->nullOnDelete();
            $table->string('topic_label');
            $table->string('topic_custom')->nullable();
            $table->foreignId('related_option_id')->nullable()->constrained('support_options')->nullOnDelete();
            $table->string('related_label');
            $table->string('related_custom')->nullable();
            $table->text('message')->nullable();
            $table->string('status', 20)->default('new');
            $table->timestamp('read_at')->nullable();
            $table->timestamps();
        });

        $now = now();
        $topics = [
            [1, 'مشكلة في الحجز', 'Booking issue', false],
            [2, 'مشكلة في الدفع أو المحفظة', 'Payment or wallet issue', false],
            [3, 'مشكلة في الحساب', 'Account issue', false],
            [4, 'استفسار عن الاشتراك', 'Subscription inquiry', false],
            [5, 'شكوى على صالون', 'Salon complaint', false],
            [6, 'مشكلة في المتجر أو طلب منتج', 'Shop or order issue', false],
            [7, 'اقتراح تحسين', 'Improvement suggestion', false],
            [8, 'أخرى', 'Other', true],
        ];
        foreach ($topics as [$order, $ar, $en, $other]) {
            DB::table('support_options')->insert([
                'field' => 'topic',
                'label' => $ar,
                'label_en' => $en,
                'is_other' => $other,
                'is_active' => true,
                'sort_order' => $order,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }

        $related = [
            [1, 'حساب عميل', 'Customer account', false],
            [2, 'حساب صاحب صالون', 'Salon owner account', false],
            [3, 'التطبيق بشكل عام', 'The app in general', false],
            [4, 'المدفوعات والمحفظة', 'Payments and wallet', false],
            [5, 'أخرى', 'Other', true],
        ];
        foreach ($related as [$order, $ar, $en, $other]) {
            DB::table('support_options')->insert([
                'field' => 'related',
                'label' => $ar,
                'label_en' => $en,
                'is_other' => $other,
                'is_active' => true,
                'sort_order' => $order,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('support_tickets');
        Schema::dropIfExists('support_options');
    }
};
