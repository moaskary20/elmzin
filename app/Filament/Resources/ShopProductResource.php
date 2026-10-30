<?php

namespace App\Filament\Resources;

use App\Filament\Resources\ShopProducts\Pages\CreateShopProduct;
use App\Filament\Resources\ShopProducts\Pages\EditShopProduct;
use App\Filament\Resources\ShopProducts\Pages\ListShopProducts;
use App\Models\ShopProduct;
use BackedEnum;
use Filament\Actions\BulkActionGroup;
use Filament\Actions\DeleteBulkAction;
use Filament\Actions\EditAction;
use Filament\Forms\Components\FileUpload;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\ImageColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;

class ShopProductResource extends Resource
{
    protected static ?string $model = ShopProduct::class;

    protected static ?string $navigationLabel = 'المنتجات';

    protected static ?string $modelLabel = 'منتج';

    protected static ?string $pluralModelLabel = 'المنتجات';

    protected static ?string $recordTitleAttribute = 'name';

    protected static bool $hasTitleCaseModelLabel = false;

    protected static string|\UnitEnum|null $navigationGroup = 'التسوق';

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedShoppingBag;

    protected static ?int $navigationSort = 2;

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('بيانات المنتج')
                ->schema([
                    Select::make('shop_category_id')
                        ->label('القسم')
                        ->relationship('category', 'name')
                        ->required()
                        ->searchable()
                        ->preload()
                        ->native(false),
                    TextInput::make('name')
                        ->label('اسم المنتج (عربي)')
                        ->required()
                        ->maxLength(255),
                    TextInput::make('name_en')
                        ->label('اسم المنتج (English)')
                        ->maxLength(255),
                    Textarea::make('description')
                        ->label('الوصف (عربي)')
                        ->rows(4)
                        ->columnSpanFull(),
                    Textarea::make('description_en')
                        ->label('الوصف (English)')
                        ->rows(4)
                        ->columnSpanFull(),
                    TextInput::make('price')
                        ->label('السعر')
                        ->numeric()
                        ->required()
                        ->minValue(0)
                        ->suffix('ج.م'),
                    TextInput::make('compare_at_price')
                        ->label('السعر قبل الخصم')
                        ->numeric()
                        ->minValue(0)
                        ->suffix('ج.م'),
                    TextInput::make('stock')
                        ->label('المخزون')
                        ->numeric()
                        ->required()
                        ->default(0)
                        ->minValue(0),
                    TextInput::make('sort_order')
                        ->label('الترتيب')
                        ->numeric()
                        ->default(0)
                        ->required(),
                    Toggle::make('is_active')
                        ->label('ظاهر للبيع')
                        ->default(true),
                    FileUpload::make('image')
                        ->label('صورة المنتج')
                        ->image()
                        ->disk('public')
                        ->directory('shop/products')
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
                ImageColumn::make('image')
                    ->label('صورة')
                    ->disk('public')
                    ->square(),
                TextColumn::make('name')
                    ->label('المنتج')
                    ->searchable()
                    ->sortable(),
                TextColumn::make('category.name')
                    ->label('القسم')
                    ->badge()
                    ->sortable(),
                TextColumn::make('price')
                    ->label('السعر')
                    ->money('EGP')
                    ->sortable(),
                TextColumn::make('stock')
                    ->label('المخزون')
                    ->sortable(),
                IconColumn::make('is_active')
                    ->label('ظاهر')
                    ->boolean(),
            ])
            ->defaultSort('sort_order')
            ->reorderable('sort_order')
            ->filters([
                SelectFilter::make('shop_category_id')
                    ->label('القسم')
                    ->relationship('category', 'name'),
            ])
            ->recordActions([
                EditAction::make(),
            ])
            ->toolbarActions([
                BulkActionGroup::make([
                    DeleteBulkAction::make(),
                ]),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => ListShopProducts::route('/'),
            'create' => CreateShopProduct::route('/create'),
            'edit' => EditShopProduct::route('/{record}/edit'),
        ];
    }
}
