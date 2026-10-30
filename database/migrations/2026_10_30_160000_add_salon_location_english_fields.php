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
            if (! Schema::hasColumn('salons', 'city_en')) {
                $table->string('city_en')->nullable()->after('city');
            }
            if (! Schema::hasColumn('salons', 'district_en')) {
                $table->string('district_en')->nullable()->after('district');
            }
            if (! Schema::hasColumn('salons', 'address_en')) {
                $table->string('address_en')->nullable()->after('address');
            }
        });

        $locations = [
            1 => [
                'city_en' => 'Cairo',
                'district_en' => 'Nasr City',
                'address_en' => 'Abbas Al-Akkad St., above Al-Nokhba Cafe, Nasr City, Cairo, Egypt',
            ],
            2 => [
                'city_en' => 'Giza',
                'district_en' => 'Mohandessin',
                'address_en' => 'Shehab St., Al-Andalus Tower, 3rd floor, Mohandessin, Giza, Egypt',
            ],
            3 => [
                'city_en' => 'Cairo',
                'district_en' => 'New Cairo',
                'address_en' => 'North 90 St., Al-Hadiqa Mall, New Cairo, Cairo, Egypt',
            ],
            4 => [
                'city_en' => 'Cairo',
                'district_en' => 'Maadi',
                'address_en' => 'Street 9, Maadi, Cairo, Egypt',
            ],
            5 => [
                'city_en' => 'Cairo',
                'district_en' => 'Zamalek',
                'address_en' => 'Brazil St., Zamalek, Cairo, Egypt',
            ],
            6 => [
                'city_en' => 'Giza',
                'district_en' => 'Dokki',
                'address_en' => 'Tahrir St., Dokki, Giza, Egypt',
            ],
            7 => [
                'city_en' => 'Cairo',
                'district_en' => 'Nasr City',
                'address_en' => 'Abbas Al-Akkad St., Nasr City, Cairo, Egypt',
            ],
            12 => [
                'city_en' => 'Cairo',
                'district_en' => 'Qasr El Nil',
                'address_en' => '1 Mohamed Mahmoud St., Tahrir Square, Qasr El Nil, Cairo, Egypt',
            ],
        ];

        foreach ($locations as $id => $payload) {
            DB::table('salons')->where('id', $id)->update($payload);
        }

        // Name-based fallback for renamed or reseeded rows.
        foreach ([
            'حماده' => [
                'city_en' => 'Cairo',
                'district_en' => 'Qasr El Nil',
                'address_en' => '1 Mohamed Mahmoud St., Tahrir Square, Qasr El Nil, Cairo, Egypt',
            ],
            'ali style' => [
                'city_en' => 'Cairo',
                'district_en' => 'Nasr City',
                'address_en' => 'Nasr City, Cairo, Egypt',
            ],
        ] as $name => $payload) {
            DB::table('salons')->where('name', $name)->where(function ($query): void {
                $query->whereNull('address_en')->orWhere('address_en', '');
            })->update($payload);
        }

        foreach ([
            'كريم محمود' => 'Karim Mahmoud',
            'يوسف عادل' => 'Youssef Adel',
        ] as $ar => $en) {
            DB::table('specialists')->where('name', $ar)->where(function ($query): void {
                $query->whereNull('name_en')->orWhere('name_en', '');
            })->update(['name_en' => $en]);
        }
    }

    public function down(): void
    {
        Schema::table('salons', function (Blueprint $table) {
            foreach (['city_en', 'district_en', 'address_en'] as $column) {
                if (Schema::hasColumn('salons', $column)) {
                    $table->dropColumn($column);
                }
            }
        });
    }
};
