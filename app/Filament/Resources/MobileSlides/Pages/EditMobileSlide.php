<?php

namespace App\Filament\Resources\MobileSlides\Pages;

use App\Filament\Resources\MobileSlideResource;
use Filament\Actions\DeleteAction;
use Filament\Resources\Pages\EditRecord;

class EditMobileSlide extends EditRecord
{
    protected static string $resource = MobileSlideResource::class;

    protected function getHeaderActions(): array
    {
        return [
            DeleteAction::make(),
        ];
    }
}
