<?php

namespace App\Filament\Resources\MobileSlides\Pages;

use App\Filament\Resources\MobileSlideResource;
use Filament\Actions\CreateAction;
use Filament\Resources\Pages\ListRecords;

class ListMobileSlides extends ListRecords
{
    protected static string $resource = MobileSlideResource::class;

    protected function getHeaderActions(): array
    {
        return [
            CreateAction::make(),
        ];
    }
}
