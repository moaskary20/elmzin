<?php

namespace App\Filament\Resources\Users\RelationManagers;

use App\Enums\WalletTransactionType;
use App\Models\User;
use App\Services\WalletService;
use Filament\Actions\Action;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Notifications\Notification;
use Filament\Resources\RelationManagers\RelationManager;
use Filament\Schemas\Schema;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
use Illuminate\Support\Facades\Auth;

class WalletTransactionsRelationManager extends RelationManager
{
    protected static string $relationship = 'walletTransactions';

    protected static ?string $title = 'المحفظة';

    protected static ?string $modelLabel = 'حركة محفظة';

    protected static ?string $pluralModelLabel = 'حركات محفظة';

    protected static bool $isLazy = false;

    public function form(Schema $schema): Schema
    {
        return $schema->components([]);
    }

    public function table(Table $table): Table
    {
        return $table
            ->description(fn (): string => 'الرصيد الحالي: '.number_format((float) $this->getOwnerRecord()->wallet_balance, 2).' ج.م')
            ->columns([
                TextColumn::make('created_at')
                    ->label('التاريخ')
                    ->dateTime('Y-m-d H:i'),
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
                    ->placeholder('—'),
                TextColumn::make('creator.name')
                    ->label('بواسطة')
                    ->placeholder('النظام'),
            ])
            ->defaultSort('id', 'desc')
            ->headerActions([
                Action::make('walletTransaction')
                    ->label('حركة على المحفظة')
                    ->icon('heroicon-o-wallet')
                    ->schema([
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
                            ->rows(2),
                    ])
                    ->action(function (array $data): void {
                        $user = $this->getOwnerRecord();

                        if (! $user instanceof User) {
                            return;
                        }

                        $type = $data['type'] instanceof WalletTransactionType
                            ? $data['type']
                            : WalletTransactionType::from($data['type']);

                        app(WalletService::class)->post(
                            $user,
                            $type,
                            (float) $data['amount'],
                            $data['note'],
                            createdBy: Auth::id(),
                        );

                        Notification::make()
                            ->title('تم تحديث المحفظة')
                            ->success()
                            ->send();
                    }),
            ]);
    }
}
