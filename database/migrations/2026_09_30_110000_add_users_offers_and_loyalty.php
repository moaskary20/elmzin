<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('phone')->nullable()->unique();
            $table->string('role')->default('customer');
            $table->boolean('is_active')->default(true);
            $table->string('city')->nullable();
            $table->integer('loyalty_points')->default(0);
        });

        DB::table('users')->where('email', 'admin@muzayen.test')->update(['role' => 'admin']);

        Schema::create('coupons', function (Blueprint $table) {
            $table->id();
            $table->string('code')->unique();
            $table->string('title');
            $table->text('description')->nullable();
            $table->string('type');
            $table->decimal('value', 10, 2);
            $table->decimal('min_amount', 10, 2)->default(0);
            $table->decimal('max_discount', 10, 2)->nullable();
            $table->unsignedInteger('usage_limit')->nullable();
            $table->unsignedInteger('usage_limit_per_user')->nullable();
            $table->timestamp('starts_at')->nullable();
            $table->timestamp('ends_at')->nullable();
            $table->boolean('is_active')->default(true);
            $table->boolean('first_booking_only')->default(false);
            $table->timestamps();
        });

        Schema::create('coupon_salon', function (Blueprint $table) {
            $table->foreignId('coupon_id')->constrained()->cascadeOnDelete();
            $table->foreignId('salon_id')->constrained()->cascadeOnDelete();
            $table->primary(['coupon_id', 'salon_id']);
        });

        Schema::table('bookings', function (Blueprint $table) {
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('coupon_id')->nullable()->constrained()->nullOnDelete();
            $table->decimal('subtotal', 10, 2)->default(0);
            $table->decimal('discount_amount', 10, 2)->default(0);
            $table->unsignedInteger('points_redeemed')->default(0);
            $table->decimal('points_discount', 10, 2)->default(0);
            $table->decimal('total', 10, 2)->default(0);
            $table->unsignedInteger('points_awarded')->default(0);
        });

        Schema::create('coupon_redemptions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('coupon_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('booking_id')->nullable()->unique()->constrained()->cascadeOnDelete();
            $table->decimal('discount_amount', 10, 2);
            $table->timestamps();
        });

        Schema::create('loyalty_settings', function (Blueprint $table) {
            $table->id();
            $table->boolean('is_active')->default(true);
            $table->decimal('earn_amount', 10, 2)->default(10);
            $table->unsignedInteger('earn_points')->default(1);
            $table->unsignedInteger('redeem_points')->default(100);
            $table->decimal('redeem_value', 10, 2)->default(10);
            $table->unsignedInteger('min_redeem_points')->default(100);
            $table->unsignedInteger('points_expire_days')->nullable();
            $table->timestamps();
        });

        Schema::create('loyalty_transactions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('booking_id')->nullable()->constrained()->nullOnDelete();
            $table->string('type');
            $table->integer('points');
            $table->integer('balance_after')->default(0);
            $table->string('note')->nullable();
            $table->timestamp('expires_at')->nullable();
            $table->timestamp('processed_at')->nullable();
            $table->timestamps();

            $table->index(['user_id', 'type']);
        });

        $prices = DB::table('services')->pluck('price', 'id');

        DB::table('bookings')->orderBy('id')->lazy()->each(function (object $booking) use ($prices): void {
            $price = $prices[$booking->service_id] ?? 0;

            DB::table('bookings')->where('id', $booking->id)->update([
                'subtotal' => $price,
                'total' => $price,
            ]);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('loyalty_transactions');
        Schema::dropIfExists('loyalty_settings');
        Schema::dropIfExists('coupon_redemptions');

        Schema::table('bookings', function (Blueprint $table) {
            $table->dropConstrainedForeignId('user_id');
            $table->dropConstrainedForeignId('coupon_id');
            $table->dropColumn([
                'subtotal',
                'discount_amount',
                'points_redeemed',
                'points_discount',
                'total',
                'points_awarded',
            ]);
        });

        Schema::dropIfExists('coupon_salon');
        Schema::dropIfExists('coupons');

        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['phone', 'role', 'is_active', 'city', 'loyalty_points']);
        });
    }
};
