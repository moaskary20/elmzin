<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

return new class extends Migration
{
    public function up(): void
    {
        $salonId = DB::table('salons')->where('name', 'صالون الليث')->value('id');
        if (! $salonId) {
            return;
        }

        $disk = Storage::disk('public');
        $files = [
            'salons/layth.jpg',
            'salons/layth-2.jpg',
            'salons/layth-3.jpg',
            'salons/layth-4.jpg',
        ];

        $order = 1;
        foreach ($files as $path) {
            if (! $disk->exists($path)) {
                continue;
            }

            $exists = DB::table('salon_media')
                ->where('salon_id', $salonId)
                ->where('path', $path)
                ->exists();

            if ($exists) {
                DB::table('salon_media')
                    ->where('salon_id', $salonId)
                    ->where('path', $path)
                    ->update([
                        'sort_order' => $order,
                        'type' => 'image',
                        'updated_at' => now(),
                    ]);
            } else {
                DB::table('salon_media')->insert([
                    'salon_id' => $salonId,
                    'type' => 'image',
                    'path' => $path,
                    'sort_order' => $order,
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
            }
            $order++;
        }

        if ($disk->exists('salons/layth.jpg')) {
            DB::table('salons')->where('id', $salonId)->update([
                'image' => 'salons/layth.jpg',
            ]);
        }
    }

    public function down(): void
    {
        $salonId = DB::table('salons')->where('name', 'صالون الليث')->value('id');
        if (! $salonId) {
            return;
        }

        DB::table('salon_media')
            ->where('salon_id', $salonId)
            ->whereIn('path', [
                'salons/layth-2.jpg',
                'salons/layth-3.jpg',
                'salons/layth-4.jpg',
            ])
            ->delete();
    }
};
