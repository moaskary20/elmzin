<?php

namespace App\Filament\Resources\ShopCategories\Pages;

use App\Filament\Resources\ShopCategoryResource;
use App\Models\ShopCategory;
use Filament\Actions\CreateAction;
use Filament\Resources\Pages\ManageRecords;
use Illuminate\Support\Str;

class ManageShopCategories extends ManageRecords
{
    protected static string $resource = ShopCategoryResource::class;

    protected function getHeaderActions(): array
    {
        return [
            CreateAction::make()
                ->label('إضافة قسم')
                ->mutateDataUsing(function (array $data): array {
                    if (blank($data['slug'] ?? null) && filled($data['name'] ?? null)) {
                        $data['slug'] = Str::slug($data['name']) ?: Str::random(8);
                    }

                    if (! isset($data['sort_order'])) {
                        $data['sort_order'] = (int) ShopCategory::query()->max('sort_order') + 1;
                    }

                    return $data;
                }),
        ];
    }
}
