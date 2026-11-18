<?php

namespace App\Filament\Resources\SupportOptions\Pages;

use App\Filament\Resources\SupportOptionResource;
use Filament\Actions\CreateAction;
use Filament\Resources\Pages\ListRecords;

class ListSupportOptions extends ListRecords
{
    protected static string $resource = SupportOptionResource::class;

    protected function getHeaderActions(): array
    {
        return [
            CreateAction::make()->label('إضافة خيار'),
        ];
    }
}
