<?php

namespace App\Filament\Resources;

use App\Enums\ShopOrderStatus;
use App\Filament\Resources\ShopOrders\Pages\EditShopOrder;
use App\Filament\Resources\ShopOrders\Pages\ListShopOrders;
use App\Filament\Resources\ShopOrders\RelationManagers\ItemsRelationManager;
use App\Models\ShopOrder;
use BackedEnum;
use Filament\Actions\EditAction;
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

class ShopOrderResource extends Resource
{
    protected static ?string $model = ShopOrder::class;

    protected static ?string $navigationLabel = 'الطلبات';

    protected static ?string $modelLabel = 'طلب';

    protected static ?string $pluralModelLabel = 'الطلبات';

    protected static bool $hasTitleCaseModelLabel = false;

    protected static string|\UnitEnum|null $navigationGroup = 'التسوق';

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedClipboardDocumentList;

    protected static ?int $navigationSort = 3;

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('بيانات العميل')
                ->schema([
                    TextInput::make('customer_name')
                        ->label('اسم العميل')
                        ->required()
                        ->maxLength(120),
                    TextInput::make('customer_phone')
                        ->label('الهاتف')
                        ->tel()
                        ->required()
                        ->maxLength(30),
                    TextInput::make('customer_address')
                        ->label('العنوان')
                        ->maxLength(255)
                        ->columnSpanFull(),
                    Select::make('user_id')
                        ->label('حساب التطبيق')
                        ->relationship('user', 'name')
                        ->searchable()
                        ->preload()
                        ->native(false),
                    Select::make('status')
                        ->label('حالة الطلب')
                        ->options(ShopOrderStatus::class)
                        ->required()
                        ->native(false),
                    Select::make('payment_method')
                        ->label('طريقة الدفع')
                        ->options([
                            'cash' => 'عند الاستلام',
                            'card' => 'بطاقة',
                        ])
                        ->required()
                        ->native(false),
                    TextInput::make('card_last4')
                        ->label('آخر ٤ أرقام')
                        ->maxLength(4)
                        ->disabled()
                        ->dehydrated(false),
                    TextInput::make('total')
                        ->label('الإجمالي')
                        ->numeric()
                        ->suffix('ج.م')
                        ->disabled()
                        ->dehydrated(false),
                    Textarea::make('notes')
                        ->label('ملاحظات')
                        ->rows(3)
                        ->columnSpanFull(),
                ])
                ->columns(2)
                ->columnSpanFull(),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->description('طلبات شراء المنتجات من التطبيق.')
            ->columns([
                TextColumn::make('id')
                    ->label('#')
                    ->sortable(),
                TextColumn::make('customer_name')
                    ->label('العميل')
                    ->searchable()
                    ->sortable(),
                TextColumn::make('customer_phone')
                    ->label('الهاتف')
                    ->searchable()
                    ->copyable(),
                TextColumn::make('items_count')
                    ->counts('items')
                    ->label('العناصر'),
                TextColumn::make('total')
                    ->label('الإجمالي')
                    ->money('EGP')
                    ->sortable(),
                TextColumn::make('payment_method')
                    ->label('الدفع')
                    ->formatStateUsing(fn (?string $state): string => match ($state) {
                        'card' => 'بطاقة',
                        default => 'استلام',
                    })
                    ->badge(),
                TextColumn::make('status')
                    ->label('الحالة')
                    ->badge()
                    ->sortable(),
                TextColumn::make('created_at')
                    ->label('تاريخ الطلب')
                    ->dateTime('Y-m-d H:i')
                    ->sortable(),
            ])
            ->defaultSort('id', 'desc')
            ->filters([
                SelectFilter::make('status')
                    ->label('الحالة')
                    ->options(ShopOrderStatus::class),
            ])
            ->recordActions([
                EditAction::make()->label('عرض'),
            ]);
    }

    public static function getRelations(): array
    {
        return [
            ItemsRelationManager::class,
        ];
    }

    public static function getPages(): array
    {
        return [
            'index' => ListShopOrders::route('/'),
            'edit' => EditShopOrder::route('/{record}/edit'),
        ];
    }
}
