<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('seller_profiles', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('national_id', 14)->nullable();
            $table->string('national_id_image')->nullable();
            $table->string('commercial_register_image')->nullable();
            $table->string('verification_status', 20)->default('pending');
            $table->boolean('is_active')->default(true);
            $table->timestamps();

            $table->unique('user_id');
        });

        Schema::create('seller_subscriptions', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('subscription_plan_id')->nullable()->constrained('subscription_plans')->nullOnDelete();
            $table->string('plan_name');
            $table->string('pricing_type', 20)->default('fixed');
            $table->decimal('price', 10, 2)->default(0);
            $table->decimal('commission_percent', 5, 2)->nullable();
            $table->timestamp('starts_at');
            $table->timestamp('ends_at');
            $table->string('status', 20)->default('active');
            $table->timestamp('terms_accepted_at')->nullable();
            $table->text('notes')->nullable();
            $table->timestamps();

            $table->index(['user_id', 'status']);
        });

        Schema::table('shop_products', function (Blueprint $table): void {
            $table->foreignId('user_id')->nullable()->after('shop_category_id')->constrained()->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('shop_products', function (Blueprint $table): void {
            $table->dropConstrainedForeignId('user_id');
        });

        Schema::dropIfExists('seller_subscriptions');
        Schema::dropIfExists('seller_profiles');
    }
};
