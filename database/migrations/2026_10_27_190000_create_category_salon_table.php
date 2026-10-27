<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('category_salon', function (Blueprint $table) {
            $table->id();
            $table->foreignId('category_id')->constrained()->cascadeOnDelete();
            $table->foreignId('salon_id')->constrained()->cascadeOnDelete();
            $table->unique(['category_id', 'salon_id']);
        });

        $rows = DB::table('salons')
            ->whereNotNull('category_id')
            ->get(['id', 'category_id']);

        foreach ($rows as $row) {
            DB::table('category_salon')->insertOrIgnore([
                'category_id' => $row->category_id,
                'salon_id' => $row->id,
            ]);
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('category_salon');
    }
};
