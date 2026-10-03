<?php

namespace App\Filament\Resources\Users\RelationManagers;

use App\Filament\Resources\BookingResource;
use App\Models\Booking;
use Filament\Resources\RelationManagers\RelationManager;
use Filament\Schemas\Schema;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;

class BookingsRelationManager extends RelationManager
{
    protected static string $relationship = 'bookings';

    protected static ?string $title = 'الحجوزات';

    protected static ?string $modelLabel = 'حجز';

    protected static ?string $pluralModelLabel = 'حجوزات';

    protected static bool $isLazy = false;

    public function form(Schema $schema): Schema
    {
        return $schema->components([]);
    }

    public function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('salon.name')
                    ->label('الصالون'),
                TextColumn::make('booked_on')
                    ->label('التاريخ')
                    ->date('Y-m-d'),
                TextColumn::make('booked_time')
                    ->label('الوقت'),
                TextColumn::make('status')
                    ->label('الحالة')
                    ->badge(),
                TextColumn::make('total')
                    ->label('الإجمالي')
                    ->suffix(' ج.م'),
            ])
            ->defaultSort('booked_on', 'desc')
            ->recordUrl(fn (Booking $record): string => BookingResource::getUrl('edit', ['record' => $record]));
    }
}
