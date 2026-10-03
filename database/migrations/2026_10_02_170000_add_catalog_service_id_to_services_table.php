<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('services', function (Blueprint $table) {
            $table->foreignId('catalog_service_id')
                ->nullable()
                ->after('salon_id')
                ->constrained('catalog_services')
                ->nullOnDelete();
        });

        $services = DB::table('services')
            ->join('salons', 'salons.id', '=', 'services.salon_id')
            ->select('services.id', 'services.name', 'salons.category_id')
            ->get();

        foreach ($services as $service) {
            $catalogId = DB::table('catalog_services')
                ->where('name', $service->name)
                ->orderByRaw('category_id = ? desc', [$service->category_id])
                ->value('id');

            if ($catalogId) {
                DB::table('services')->where('id', $service->id)->update(['catalog_service_id' => $catalogId]);
            }
        }
    }

    public function down(): void
    {
        Schema::table('services', function (Blueprint $table) {
            $table->dropConstrainedForeignId('catalog_service_id');
        });
    }
};
