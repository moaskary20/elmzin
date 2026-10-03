<?php

namespace App\Filament\Resources\LoyaltyTransactions\Pages;

use App\Filament\Resources\LoyaltyTransactionResource;
use Filament\Actions\CreateAction;
use Filament\Resources\Pages\ListRecords;

class ListLoyaltyTransactions extends ListRecords
{
    protected static string $resource = LoyaltyTransactionResource::class;

    protected function getHeaderActions(): array
    {
        return [
            CreateAction::make()->label('تعديل رصيد'),
        ];
    }
}
