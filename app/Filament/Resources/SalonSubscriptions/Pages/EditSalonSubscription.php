<?php

namespace App\Filament\Resources\SalonSubscriptions\Pages;

use App\Filament\Resources\SalonSubscriptionResource;
use Filament\Actions\DeleteAction;
use Filament\Resources\Pages\EditRecord;

class EditSalonSubscription extends EditRecord
{
    protected static string $resource = SalonSubscriptionResource::class;

    protected function getHeaderActions(): array
    {
        return [
            DeleteAction::make(),
        ];
    }
}
