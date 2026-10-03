<?php

namespace App\Filament\Resources\SalonSubscriptions\Pages;

use App\Filament\Resources\SalonSubscriptionResource;
use Filament\Actions\CreateAction;
use Filament\Resources\Pages\ListRecords;

class ListSalonSubscriptions extends ListRecords
{
    protected static string $resource = SalonSubscriptionResource::class;

    protected function getHeaderActions(): array
    {
        return [
            CreateAction::make(),
        ];
    }
}
