<?php

namespace App\Filament\Resources\Coupons\RelationManagers;

use Filament\Resources\RelationManagers\RelationManager;
use Filament\Schemas\Schema;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;

class RedemptionsRelationManager extends RelationManager
{
    protected static string $relationship = 'redemptions';

    protected static ?string $title = 'سجل الاستخدام';

    protected static ?string $modelLabel = 'استخدام';

    protected static ?string $pluralModelLabel = 'استخدامات';

    protected static bool $isLazy = false;

    public function form(Schema $schema): Schema
    {
        return $schema->components([]);
    }

    public function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('user.name')
                    ->label('المستخدم')
                    ->placeholder('بدون حساب'),
                TextColumn::make('booking_id')
                    ->label('الحجز')
                    ->prefix('#'),
                TextColumn::make('discount_amount')
                    ->label('الخصم')
                    ->suffix(' ج.م'),
                TextColumn::make('created_at')
                    ->label('التاريخ')
                    ->dateTime('Y-m-d H:i'),
            ])
            ->defaultSort('id', 'desc');
    }
}
