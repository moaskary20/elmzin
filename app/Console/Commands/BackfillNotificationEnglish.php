<?php

namespace App\Console\Commands;

use App\Models\AppNotification;
use App\Services\NotificationLocalizer;
use Illuminate\Console\Command;

class BackfillNotificationEnglish extends Command
{
    protected $signature = 'notifications:backfill-en';

    protected $description = 'Fill missing English title/body on existing notifications';

    public function handle(NotificationLocalizer $localizer): int
    {
        $updated = 0;

        AppNotification::query()
            ->where(function ($query): void {
                $query->whereNull('title_en')->orWhere('title_en', '')
                    ->orWhereNull('body_en')->orWhere('body_en', '');
            })
            ->orderBy('id')
            ->chunkById(100, function ($rows) use ($localizer, &$updated): void {
                foreach ($rows as $item) {
                    $english = $localizer->english($item);
                    if (! filled($english['title_en']) && ! filled($english['body_en'])) {
                        continue;
                    }

                    $item->forceFill([
                        'title_en' => $english['title_en'] ?: $item->title_en,
                        'body_en' => $english['body_en'] ?: $item->body_en,
                    ])->saveQuietly();
                    $updated++;
                }
            });

        $this->info("Updated {$updated} notifications.");

        return self::SUCCESS;
    }
}
