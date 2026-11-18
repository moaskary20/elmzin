<?php

namespace App\Filament\Resources\SupportOptions\Pages;

use App\Filament\Resources\SupportOptionResource;
use Filament\Actions\DeleteAction;
use Filament\Resources\Pages\EditRecord;

class EditSupportOption extends EditRecord
{
    protected static string $resource = SupportOptionResource::class;

    protected function getHeaderActions(): array
    {
        return [
            DeleteAction::make(),
        ];
    }
}
