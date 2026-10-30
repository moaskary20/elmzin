<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('app_notifications', function (Blueprint $table): void {
            if (! Schema::hasColumn('app_notifications', 'title_en')) {
                $table->string('title_en')->nullable()->after('title');
            }
            if (! Schema::hasColumn('app_notifications', 'body_en')) {
                $table->text('body_en')->nullable()->after('body');
            }
        });
    }

    public function down(): void
    {
        Schema::table('app_notifications', function (Blueprint $table): void {
            if (Schema::hasColumn('app_notifications', 'body_en')) {
                $table->dropColumn('body_en');
            }
            if (Schema::hasColumn('app_notifications', 'title_en')) {
                $table->dropColumn('title_en');
            }
        });
    }
};
