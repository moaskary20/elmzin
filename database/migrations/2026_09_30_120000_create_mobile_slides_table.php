<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('mobile_slides', function (Blueprint $table) {
            $table->id();
            $table->string('image');
            $table->string('title');
            $table->text('subtitle')->nullable();
            $table->string('title_en')->nullable();
            $table->text('subtitle_en')->nullable();
            $table->unsignedInteger('sort_order')->default(0);
            $table->boolean('is_active')->default(true);
            $table->timestamps();
        });

        $directory = storage_path('app/public/slides');

        if (! is_dir($directory)) {
            mkdir($directory, 0755, true);
        }

        $source = base_path('mobile/asset/slid1.jpg');

        if (is_file($source)) {
            copy($source, $directory.'/slid1.jpg');
        }

        DB::table('mobile_slides')->insert([
            'image' => 'slides/slid1.jpg',
            'title' => 'الكرسي بانتظارك',
            'subtitle' => 'مواعيد فورية في أرقى صالونات ومحلات الحلاقة. اختر المصفف، حدد الموعد، واحضر.',
            'title_en' => 'Your chair is waiting',
            'subtitle_en' => 'Instant appointments at the finest salons and barbershops. Choose the stylist, pick a time, and show up.',
            'sort_order' => 1,
            'is_active' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    public function down(): void
    {
        Schema::dropIfExists('mobile_slides');
    }
};
