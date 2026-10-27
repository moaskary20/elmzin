<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        $rows = [
            1 => [
                'address' => 'شارع عباس العقاد، أعلى كافيه النخبة، مدينة نصر، القاهرة، مصر',
                'city' => 'القاهرة',
                'district' => 'مدينة نصر',
            ],
            2 => [
                'address' => 'شارع شهاب، برج الأندلس، الدور الثالث، المهندسين، الجيزة، مصر',
                'city' => 'الجيزة',
                'district' => 'المهندسين',
            ],
            3 => [
                'address' => 'التسعين الشمالي، مول الحديقة، التجمع الخامس، القاهرة، مصر',
                'city' => 'القاهرة',
                'district' => 'التجمع الخامس',
            ],
            4 => [
                'address' => 'شارع 9، المعادي، القاهرة، مصر',
                'city' => 'القاهرة',
                'district' => 'المعادي',
            ],
            5 => [
                'address' => 'شارع البرازيل، الزمالك، القاهرة، مصر',
                'city' => 'القاهرة',
                'district' => 'الزمالك',
            ],
            6 => [
                'address' => 'شارع التحرير، الدقي، الجيزة، مصر',
                'city' => 'الجيزة',
                'district' => 'الدقي',
            ],
            7 => [
                'address' => 'شارع عباس العقاد، مدينة نصر، القاهرة، مصر',
                'city' => 'القاهرة',
                'district' => 'مدينة نصر',
            ],
            12 => [
                'address' => '1 شارع محمد محمود، ميدان التحرير، قصر النيل، القاهرة، مصر',
                'city' => 'القاهرة',
                'district' => 'قصر النيل',
            ],
            13 => [
                'address' => '1 شارع محمد محمود، ميدان التحرير، قصر النيل، القاهرة، مصر',
                'city' => 'القاهرة',
                'district' => 'قصر النيل',
            ],
        ];

        foreach ($rows as $id => $data) {
            DB::table('salons')->where('id', $id)->update($data);
        }

        // Any other salon missing a street address: build one from district/city.
        DB::table('salons')
            ->where(function ($query): void {
                $query->whereNull('address')->orWhere('address', '');
            })
            ->orderBy('id')
            ->get(['id', 'name', 'city', 'district'])
            ->each(function ($salon): void {
                $parts = array_filter([
                    $salon->district,
                    $salon->city,
                    'مصر',
                ]);
                DB::table('salons')->where('id', $salon->id)->update([
                    'address' => implode('، ', $parts) ?: 'القاهرة، مصر',
                    'city' => filled($salon->city) && $salon->city !== 'غير محدد'
                        ? $salon->city
                        : 'القاهرة',
                    'district' => $salon->district ?: 'وسط البلد',
                ]);
            });
    }

    public function down(): void
    {
        //
    }
};
