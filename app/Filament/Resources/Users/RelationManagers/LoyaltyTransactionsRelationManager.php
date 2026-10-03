<?php

namespace App\Filament\Resources\Users\RelationManagers;

use App\Models\User;
use App\Services\OfferService;
use Filament\Actions\Action;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Notifications\Notification;
use Filament\Resources\RelationManagers\RelationManager;
use Filament\Schemas\Schema;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;

class LoyaltyTransactionsRelationManager extends RelationManager
{
    protected static string $relationship = 'loyaltyTransactions';

    protected static ?string $title = 'نقاط الولاء';

    protected static ?string $modelLabel = 'حركة نقاط';

    protected static ?string $pluralModelLabel = 'حركات نقاط';

    protected static bool $isLazy = false;

    public function form(Schema $schema): Schema
    {
        return $schema->components([]);
    }

    public function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('created_at')
                    ->label('التاريخ')
                    ->dateTime('Y-m-d H:i'),
                TextColumn::make('type')
                    ->label('النوع')
                    ->badge(),
                TextColumn::make('points')
                    ->label('النقاط')
                    ->formatStateUsing(fn (int $state): string => ($state > 0 ? '+' : '').$state),
                TextColumn::make('balance_after')
                    ->label('الرصيد بعد الحركة'),
                TextColumn::make('note')
                    ->label('البيان')
                    ->placeholder('—'),
                TextColumn::make('expires_at')
                    ->label('تنتهي')
                    ->date('Y-m-d')
                    ->placeholder('—'),
            ])
            ->defaultSort('id', 'desc')
            ->headerActions([
                Action::make('adjustPoints')
                    ->label('تعديل الرصيد')
                    ->schema([
                        TextInput::make('points')
                            ->label('النقاط')
                            ->numeric()
                            ->required()
                            ->helperText('رقم موجب للإضافة، وسالب للخصم.'),
                        Textarea::make('note')
                            ->label('السبب')
                            ->required()
                            ->rows(2),
                    ])
                    ->action(function (array $data): void {
                        $user = $this->getOwnerRecord();

                        if (! $user instanceof User) {
                            return;
                        }

                        app(OfferService::class)->adjust($user, (int) $data['points'], $data['note']);

                        Notification::make()
                            ->title('تم تحديث رصيد النقاط')
                            ->success()
                            ->send();
                    }),
            ]);
    }
}
