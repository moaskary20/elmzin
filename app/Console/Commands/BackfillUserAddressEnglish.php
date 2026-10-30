<?php

namespace App\Console\Commands;

use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Http;

class BackfillUserAddressEnglish extends Command
{
    protected $signature = 'users:backfill-address-en {--force : Overwrite existing English addresses}';

    protected $description = 'Fill users.address_en/city_en from Google Geocoding using stored coordinates';

    public function handle(): int
    {
        $key = config('services.google.maps_key')
            ?: env('GOOGLE_MAPS_API_KEY')
            ?: 'AIzaSyAj0tcAJXRGz4TU2OO-_l1lyS-sDVvBohs';

        $updated = 0;
        $failed = 0;

        User::query()
            ->whereNotNull('latitude')
            ->whereNotNull('longitude')
            ->when(! $this->option('force'), function ($query): void {
                $query->where(function ($inner): void {
                    $inner->whereNull('address_en')->orWhere('address_en', '');
                });
            })
            ->orderBy('id')
            ->chunkById(50, function ($users) use ($key, &$updated, &$failed): void {
                foreach ($users as $user) {
                    try {
                        $response = Http::timeout(12)->get('https://maps.googleapis.com/maps/api/geocode/json', [
                            'latlng' => $user->latitude.','.$user->longitude,
                            'language' => 'en',
                            'key' => $key,
                        ]);
                        $results = $response->json('results') ?? [];
                        if ($results === []) {
                            $failed++;

                            continue;
                        }

                        $first = $results[0];
                        $addressEn = trim((string) ($first['formatted_address'] ?? ''));
                        if ($addressEn === '') {
                            $failed++;

                            continue;
                        }

                        $cityEn = null;
                        foreach ($first['address_components'] ?? [] as $part) {
                            $types = $part['types'] ?? [];
                            if (in_array('locality', $types, true)) {
                                $cityEn = $part['long_name'] ?? null;
                                break;
                            }
                        }
                        if ($cityEn === null) {
                            foreach ($first['address_components'] ?? [] as $part) {
                                $types = $part['types'] ?? [];
                                if (in_array('administrative_area_level_1', $types, true)) {
                                    $cityEn = $part['long_name'] ?? null;
                                    break;
                                }
                            }
                        }

                        $user->forceFill([
                            'address_en' => $addressEn,
                            'city_en' => $cityEn ?: $user->city_en,
                        ])->saveQuietly();
                        $updated++;
                        usleep(120000);
                    } catch (\Throwable) {
                        $failed++;
                    }
                }
            });

        $this->info("Updated {$updated} users. Failed {$failed}.");

        return self::SUCCESS;
    }
}
