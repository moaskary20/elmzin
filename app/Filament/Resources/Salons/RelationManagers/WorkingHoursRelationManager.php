<?php

namespace App\Filament\Resources\Salons\RelationManagers;

use App\Enums\Weekday;
use Filament\Actions\CreateAction;
use Filament\Actions\DeleteAction;
use Filament\Actions\EditAction;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TimePicker;
use Filament\Forms\Components\Toggle;
use Filament\Resources\RelationManagers\RelationManager;
use Filament\Schemas\Components\Utilities\Get;
use Filament\Schemas\Schema;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;

class WorkingHoursRelationManager extends RelationManager
{
    protected static string $relationship = 'workingHours';

    protected static ?string $title = 'توقيت العمل';

    protected static ?string $modelLabel = 'يوم عمل';

    protected static ?string $pluralModelLabel = 'أيام عمل';

    protected static bool $isLazy = false;

    public function form(Schema $schema): Schema
    {
        return $schema->components([
            Select::make('day_of_week')
                ->label('اليوم')
                ->options(Weekday::class)
                ->required()
                ->native(false),
            Toggle::make('is_closed')
                ->label('إجازة')
                ->live()
                ->default(false),
            TimePicker::make('opens_at')
                ->label('من')
                ->seconds(false)
                ->required(fn (Get $get): bool => ! $get('is_closed'))
                ->disabled(fn (Get $get): bool => (bool) $get('is_closed')),
            TimePicker::make('closes_at')
                ->label('إلى')
                ->seconds(false)
                ->required(fn (Get $get): bool => ! $get('is_closed'))
                ->disabled(fn (Get $get): bool => (bool) $get('is_closed')),
        ]);
    }

    public function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('day_of_week')
                    ->label('اليوم'),
                TextColumn::make('opens_at')
                    ->label('من')
                    ->time('H:i'),
                TextColumn::make('closes_at')
                    ->label('إلى')
                    ->time('H:i'),
                IconColumn::make('is_closed')
                    ->label('إجازة')
                    ->boolean(),
            ])
            ->defaultSort('day_of_week')
            ->headerActions([
                CreateAction::make()->label('إضافة يوم'),
            ])
            ->recordActions([
                EditAction::make(),
                DeleteAction::make(),
            ]);
    }
}
