<?php

namespace App\Filament\Resources;

use App\Enums\LoyaltyTransactionType;
use App\Filament\Resources\LoyaltyTransactions\Pages\CreateLoyaltyTransaction;
use App\Filament\Resources\LoyaltyTransactions\Pages\ListLoyaltyTransactions;
use App\Models\LoyaltyTransaction;
use BackedEnum;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Model;

class LoyaltyTransactionResource extends Resource
{
    protected static ?string $model = LoyaltyTransaction::class;

    protected static ?string $navigationLabel = 'سجل النقاط';

    protected static ?string $modelLabel = 'حركة نقاط';

    protected static ?string $pluralModelLabel = 'سجل النقاط';

    protected static string|\UnitEnum|null $navigationGroup = 'العروض';

    protected static bool $hasTitleCaseModelLabel = false;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedBanknotes;

    protected static ?int $navigationSort = 3;

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('تعديل رصيد')
                ->description('حركة يدوية تُضاف إلى السجل. الاكتساب والاستبدال يتمّان من الحجوزات.')
                ->schema([
                    Select::make('user_id')
                        ->label('المستخدم')
                        ->relationship('user', 'name', fn ($query) => $query->customers()->orderBy('name'))
                        ->getOptionLabelFromRecordUsing(fn (Model $record): string => $record->name.' — '.($record->phone ?: $record->email))
                        ->searchable()
                        ->preload()
                        ->required()
                        ->native(false),
                    TextInput::make('points')
                        ->label('النقاط')
                        ->numeric()
                        ->required()
                        ->helperText('موجب للإضافة وسالب للخصم.'),
                    Textarea::make('note')
                        ->label('السبب')
                        ->required()
                        ->rows(2)
                        ->columnSpanFull(),
                ])
                ->columns(2)
                ->columnSpanFull(),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('created_at')
                    ->label('التاريخ')
                    ->dateTime('Y-m-d H:i')
                    ->sortable(),
                TextColumn::make('user.name')
                    ->label('المستخدم')
                    ->searchable(),
                TextColumn::make('type')
                    ->label('النوع')
                    ->badge(),
                TextColumn::make('points')
                    ->label('النقاط')
                    ->formatStateUsing(fn (int $state): string => ($state > 0 ? '+' : '').$state),
                TextColumn::make('balance_after')
                    ->label('الرصيد'),
                TextColumn::make('booking_id')
                    ->label('الحجز')
                    ->placeholder('—')
                    ->formatStateUsing(fn ($state): string => $state ? '#'.$state : '—'),
                TextColumn::make('note')
                    ->label('البيان')
                    ->limit(40),
                TextColumn::make('expires_at')
                    ->label('تنتهي')
                    ->date('Y-m-d')
                    ->placeholder('—'),
            ])
            ->defaultSort('id', 'desc')
            ->filters([
                SelectFilter::make('type')
                    ->label('النوع')
                    ->options(LoyaltyTransactionType::class),
                SelectFilter::make('user_id')
                    ->label('المستخدم')
                    ->relationship('user', 'name', fn ($query) => $query->customers()),
            ]);
    }

    public static function canEdit(Model $record): bool
    {
        return false;
    }

    public static function getPages(): array
    {
        return [
            'index' => ListLoyaltyTransactions::route('/'),
            'create' => CreateLoyaltyTransaction::route('/create'),
        ];
    }
}
