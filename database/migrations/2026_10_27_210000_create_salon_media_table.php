<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('salon_media', function (Blueprint $table) {
            $table->id();
            $table->foreignId('salon_id')->constrained()->cascadeOnDelete();
            $table->string('type', 20)->default('image');
            $table->string('path');
            $table->unsignedInteger('sort_order')->default(0);
            $table->timestamps();
        });

        $salons = DB::table('salons')
            ->whereNotNull('image')
            ->where('image', '!=', '')
            ->get(['id', 'image']);

        foreach ($salons as $salon) {
            DB::table('salon_media')->insert([
                'salon_id' => $salon->id,
                'type' => 'image',
                'path' => $salon->image,
                'sort_order' => 0,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('salon_media');
    }
};
