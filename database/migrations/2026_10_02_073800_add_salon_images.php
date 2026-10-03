<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Storage;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('salons', function (Blueprint $table) {
            $table->string('image')->nullable()->after('name');
        });

        $photos = [
            'صالون الليث' => 'salons/layth.jpg',
            'لمسة جمال' => 'salons/lamsa.jpg',
            'براعم' => 'salons/baraem.jpg',
            'بيت الحلاقة' => 'salons/bait.jpg',
            'دار الجمال' => 'salons/dar.jpg',
            'أتيليه نور' => 'salons/atelier.jpg',
            'صالون الصغير' => 'salons/saghir.jpg',
        ];

        foreach ($photos as $name => $path) {
            if (! Storage::disk('public')->exists($path)) {
                continue;
            }

            DB::table('salons')->where('name', $name)->update(['image' => $path]);
        }
    }

    public function down(): void
    {
        Schema::table('salons', function (Blueprint $table) {
            $table->dropColumn('image');
        });
    }
};
