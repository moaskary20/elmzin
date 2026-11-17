<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('app_popups', function (Blueprint $table) {
            $table->id();
            $table->boolean('is_active')->default(false);
            $table->string('title');
            $table->string('title_en')->nullable();
            $table->text('body');
            $table->text('body_en')->nullable();
            $table->string('button_label')->default('حسناً');
            $table->string('button_label_en')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('app_popups');
    }
};
