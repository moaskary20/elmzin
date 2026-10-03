<?php

namespace App\Filament\Resources\Users\RelationManagers;

use Filament\Resources\RelationManagers\RelationManager;
use Filament\Schemas\Schema;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;

class CouponRedemptionsRelationManager extends RelationManager
{
    protected static string $relationship = 'couponRedemptions';

    protected static ?string $title = 'الكوبونات المستخدمة';

    protected static ?string $modelLabel = 'كوبون';

    protected static ?string $pluralModelLabel = 'كوبونات';

    protected static bool $isLazy = false;

    public function form(Schema $schema): Schema
    {
        return $schema->components([]);
    }

    public function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('coupon.code')
                    ->label('الكوبون'),
                TextColumn::make('coupon.title')
                    ->label('العرض'),
                TextColumn::make('discount_amount')
                    ->label('الخصم')
                    ->suffix(' ج.م'),
                TextColumn::make('booking_id')
                    ->label('الحجز')
                    ->prefix('#'),
                TextColumn::make('created_at')
                    ->label('التاريخ')
                    ->dateTime('Y-m-d H:i'),
            ])
            ->defaultSort('id', 'desc');
    }
}
