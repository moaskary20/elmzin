<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('users', 'name_en')) {
            Schema::table('users', function (Blueprint $table) {
                $table->string('name_en')->nullable()->after('name');
            });
        }

        // Copy English salon names onto salon-owner accounts for settings display.
        DB::table('salons')
            ->whereNotNull('user_id')
            ->whereNotNull('name_en')
            ->where('name_en', '!=', '')
            ->orderBy('id')
            ->get(['user_id', 'name_en'])
            ->each(function ($salon): void {
                DB::table('users')->where('id', $salon->user_id)->update([
                    'name_en' => $salon->name_en,
                ]);
            });
    }

    public function down(): void
    {
        if (Schema::hasColumn('users', 'name_en')) {
            Schema::table('users', function (Blueprint $table) {
                $table->dropColumn('name_en');
            });
        }
    }
};
