<?php

namespace App\Filament\Resources\ShopProducts\Pages;

use App\Filament\Resources\ShopProductResource;
use Filament\Resources\Pages\CreateRecord;

class CreateShopProduct extends CreateRecord
{
    protected static string $resource = ShopProductResource::class;

    protected static ?string $title = 'إضافة منتج';
}
