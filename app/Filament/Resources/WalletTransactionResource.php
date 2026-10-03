<?php

namespace App\Filament\Resources;

use App\Enums\WalletTransactionType;
use App\Filament\Resources\WalletTransactions\Pages\CreateWalletTransaction;
use App\Filament\Resources\WalletTransactions\Pages\ListWalletTransactions;
use App\Models\WalletTransaction;
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

class WalletTransactionResource extends Resource
{
    protected static ?string $model = WalletTransaction::class;

    protected static ?string $navigationLabel = 'المحفظة';

    protected static ?string $modelLabel = 'حركة محفظة';

    protected static ?string $pluralModelLabel = 'حركات المحفظة';

    protected static string|\UnitEnum|null $navigationGroup = 'العروض';

    protected static bool $hasTitleCaseModelLabel = false;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedWallet;

    protected static ?int $navigationSort = 4;

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('حركة على محفظة عميل')
                ->description('الشحن والاسترداد والمكافأة تزيد الرصيد، والدفع والخصم ينقصانه.')
                ->schema([
                    Select::make('user_id')
                        ->label('العميل')
                        ->relationship('user', 'name', fn ($query) => $query->customers()->orderBy('name'))
                        ->getOptionLabelFromRecordUsing(fn (Model $record): string => $record->name.' — '.($record->phone ?: $record->email).' — '.number_format((float) $record->wallet_balance, 2).' ج.م')
                        ->searchable()
                        ->preload()
                        ->required()
                        ->native(false),
                    Select::make('type')
                        ->label('نوع الحركة')
                        ->options(WalletTransactionType::class)
                        ->default(WalletTransactionType::Deposit->value)
                        ->required()
                        ->native(false),
                    TextInput::make('amount')
                        ->label('المبلغ')
                        ->numeric()
                        ->minValue(0.01)
                        ->prefix('ج.م')
                        ->required(),
                    Textarea::make('note')
                        ->label('البيان')
                        ->required()
                        ->rows(2)
                        ->columnSpanFull(),
                ])
                ->columns(3)
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
                    ->label('العميل')
                    ->searchable(),
                TextColumn::make('type')
                    ->label('النوع')
                    ->badge(),
                TextColumn::make('amount')
                    ->label('المبلغ')
                    ->formatStateUsing(fn ($state): string => ((float) $state > 0 ? '+' : '').number_format((float) $state, 2).' ج.م')
                    ->color(fn ($state): string => (float) $state > 0 ? 'success' : 'danger'),
                TextColumn::make('balance_after')
                    ->label('الرصيد بعد الحركة')
                    ->formatStateUsing(fn ($state): string => number_format((float) $state, 2).' ج.م'),
                TextColumn::make('note')
                    ->label('البيان')
                    ->limit(40),
                TextColumn::make('creator.name')
                    ->label('بواسطة')
                    ->placeholder('النظام'),
            ])
            ->defaultSort('id', 'desc')
            ->filters([
                SelectFilter::make('type')
                    ->label('النوع')
                    ->options(WalletTransactionType::class),
                SelectFilter::make('user_id')
                    ->label('العميل')
                    ->relationship('user', 'name', fn ($query) => $query->customers()),
            ]);
    }

    public static function canEdit(Model $record): bool
    {
        return false;
    }

    public static function canDelete(Model $record): bool
    {
        return false;
    }

    public static function getPages(): array
    {
        return [
            'index' => ListWalletTransactions::route('/'),
            'create' => CreateWalletTransaction::route('/create'),
        ];
    }
}
