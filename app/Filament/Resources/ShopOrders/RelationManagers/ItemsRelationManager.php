<?php

namespace App\Filament\Resources\ShopOrders\RelationManagers;

use Filament\Resources\RelationManagers\RelationManager;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;

class ItemsRelationManager extends RelationManager
{
    protected static string $relationship = 'items';

    protected static ?string $title = 'منتجات الطلب';

    protected static ?string $modelLabel = 'عنصر';

    protected static bool $hasTitleCaseModelLabel = false;

    public function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('product_name')
                    ->label('المنتج')
                    ->searchable(),
                TextColumn::make('price')
                    ->label('السعر')
                    ->money('EGP'),
                TextColumn::make('quantity')
                    ->label('الكمية'),
                TextColumn::make('line_total')
                    ->label('الإجمالي')
                    ->money('EGP'),
            ])
            ->paginated(false);
    }
}
