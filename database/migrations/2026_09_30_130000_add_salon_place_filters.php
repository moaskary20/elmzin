<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('salons', function (Blueprint $table) {
            $table->decimal('latitude', 10, 7)->nullable()->after('address');
            $table->decimal('longitude', 10, 7)->nullable()->after('latitude');
            $table->boolean('is_featured')->default(false)->after('is_active');
            $table->boolean('offers_home_service')->default(false)->after('is_featured');
        });

        $this->place('صالون الليث', [
            'latitude' => 30.0561000,
            'longitude' => 31.3300000,
            'is_featured' => true,
            'offers_home_service' => false,
        ]);

        $this->place('لمسة جمال', [
            'latitude' => 30.0556000,
            'longitude' => 31.2001000,
            'is_featured' => true,
            'offers_home_service' => true,
        ]);

        $this->place('براعم', [
            'latitude' => 30.0074000,
            'longitude' => 31.4913000,
            'is_featured' => true,
            'offers_home_service' => false,
        ]);

        $men = DB::table('categories')->where('slug', 'men')->value('id');
        $women = DB::table('categories')->where('slug', 'women')->value('id');
        $kids = DB::table('categories')->where('slug', 'kids')->value('id');

        if ($men) {
            $this->ensure([
                'category_id' => $men,
                'name' => 'بيت الحلاقة',
                'phone' => '01000000011',
                'city' => 'القاهرة',
                'district' => 'المعادي',
                'address' => 'شارع 9، المعادي',
                'about' => 'حلاقة منزلية وداخل الصالون.',
                'verification_status' => 'verified',
                'is_active' => true,
                'is_featured' => false,
                'offers_home_service' => true,
                'latitude' => 29.9602000,
                'longitude' => 31.2569000,
                'rating_avg' => 4.7,
                'reviews_count' => 12,
            ], [
                ['قص شعر', 100, 30],
                ['حلاقة كاملة', 150, 40],
            ]);
        }

        if ($women) {
            $this->ensure([
                'category_id' => $women,
                'name' => 'دار الجمال',
                'phone' => '01000000012',
                'city' => 'القاهرة',
                'district' => 'الزمالك',
                'address' => 'شارع البرازيل، الزمالك',
                'about' => 'تجميل داخل الصالون.',
                'verification_status' => 'verified',
                'is_active' => true,
                'is_featured' => false,
                'offers_home_service' => false,
                'latitude' => 30.0626000,
                'longitude' => 31.2197000,
                'rating_avg' => 4.9,
                'reviews_count' => 28,
            ], [
                ['صبغة شعر', 520, 90],
                ['عناية بشرة', 380, 50],
            ]);

            $this->ensure([
                'category_id' => $women,
                'name' => 'أتيليه نور',
                'phone' => '01000000014',
                'city' => 'الجيزة',
                'district' => 'الدقي',
                'address' => 'شارع التحرير، الدقي',
                'about' => 'خدمة منزلية للمكياج والتسريحات.',
                'verification_status' => 'verified',
                'is_active' => true,
                'is_featured' => false,
                'offers_home_service' => true,
                'latitude' => 30.0384000,
                'longitude' => 31.2089000,
                'rating_avg' => 4.4,
                'reviews_count' => 9,
            ], [
                ['مكياج', 250, 45],
            ]);
        }

        if ($kids) {
            $this->ensure([
                'category_id' => $kids,
                'name' => 'صالون الصغير',
                'phone' => '01000000013',
                'city' => 'القاهرة',
                'district' => 'مدينة نصر',
                'address' => 'عباس العقاد، مدينة نصر',
                'about' => 'قصات أطفال داخل الصالون.',
                'verification_status' => 'pending',
                'is_active' => true,
                'is_featured' => false,
                'offers_home_service' => false,
                'latitude' => 30.0620000,
                'longitude' => 31.3400000,
                'rating_avg' => 4.1,
                'reviews_count' => 6,
            ], [
                ['قصة أطفال', 60, 25],
            ]);
        }
    }

    public function down(): void
    {
        DB::table('salons')->whereIn('name', [
            'بيت الحلاقة',
            'دار الجمال',
            'أتيليه نور',
            'صالون الصغير',
        ])->delete();

        Schema::table('salons', function (Blueprint $table) {
            $table->dropColumn([
                'latitude',
                'longitude',
                'is_featured',
                'offers_home_service',
            ]);
        });
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    private function place(string $name, array $attributes): void
    {
        DB::table('salons')->where('name', $name)->update($attributes);
    }

    /**
     * @param  array<string, mixed>  $attributes
     * @param  array<int, array{0: string, 1: int, 2: int}>  $services
     */
    private function ensure(array $attributes, array $services): void
    {
        $existing = DB::table('salons')->where('name', $attributes['name'])->value('id');

        if ($existing) {
            DB::table('salons')->where('id', $existing)->update([
                'latitude' => $attributes['latitude'],
                'longitude' => $attributes['longitude'],
                'is_featured' => $attributes['is_featured'],
                'offers_home_service' => $attributes['offers_home_service'],
            ]);

            return;
        }

        $now = now();
        $id = DB::table('salons')->insertGetId($attributes + [
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        foreach ($services as [$name, $price, $minutes]) {
            DB::table('services')->insert([
                'salon_id' => $id,
                'name' => $name,
                'price' => $price,
                'duration_minutes' => $minutes,
                'is_active' => true,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }
    }
};
