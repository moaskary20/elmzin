<?php

namespace App\Filament\Resources\CatalogServices\Pages;

use App\Filament\Resources\CatalogServiceResource;
use App\Models\CatalogService;
use Filament\Actions\CreateAction;
use Filament\Resources\Pages\ManageRecords;

class ManageCatalogServices extends ManageRecords
{
    protected static string $resource = CatalogServiceResource::class;

    protected function getHeaderActions(): array
    {
        return [
            CreateAction::make()
                ->label('إضافة خدمة')
                ->mutateDataUsing(function (array $data): array {
                    $data['sort_order'] = (int) CatalogService::query()
                        ->where('category_id', $data['category_id'])
                        ->max('sort_order') + 1;

                    return $data;
                }),
        ];
    }
}
