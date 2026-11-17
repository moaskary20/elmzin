<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('subscription_plans', function (Blueprint $table): void {
            $table->string('pricing_type', 20)->default('fixed')->after('badge_en');
            $table->decimal('commission_percent', 5, 2)->nullable()->after('price');
        });

        Schema::table('salon_subscriptions', function (Blueprint $table): void {
            $table->string('pricing_type', 20)->default('fixed')->after('plan_name');
            $table->decimal('commission_percent', 5, 2)->nullable()->after('price');
        });
    }

    public function down(): void
    {
        Schema::table('subscription_plans', function (Blueprint $table): void {
            $table->dropColumn(['pricing_type', 'commission_percent']);
        });

        Schema::table('salon_subscriptions', function (Blueprint $table): void {
            $table->dropColumn(['pricing_type', 'commission_percent']);
        });
    }
};
