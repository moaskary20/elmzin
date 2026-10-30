<?php

namespace App\Filament\Resources;

use App\Filament\Resources\ShopCategories\Pages\ManageShopCategories;
use App\Models\ShopCategory;
use BackedEnum;
use Filament\Actions\DeleteAction;
use Filament\Actions\EditAction;
use Filament\Forms\Components\FileUpload;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\ImageColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
class ShopCategoryResource extends Resource
{
    protected static ?string $model = ShopCategory::class;

    protected static ?string $navigationLabel = 'الأقسام';

    protected static ?string $modelLabel = 'قسم تسوق';

    protected static ?string $pluralModelLabel = 'أقسام التسوق';

    protected static ?string $recordTitleAttribute = 'name';

    protected static bool $hasTitleCaseModelLabel = false;

    protected static string|\UnitEnum|null $navigationGroup = 'التسوق';

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedTag;

    protected static ?int $navigationSort = 1;

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            TextInput::make('name')
                ->label('اسم القسم (عربي)')
                ->required()
                ->maxLength(255),
            TextInput::make('name_en')
                ->label('اسم القسم (English)')
                ->maxLength(255),
            TextInput::make('slug')
                ->label('المعرّف')
                ->required()
                ->unique(ignoreRecord: true)
                ->maxLength(255)
                ->helperText('مثال: hair-care'),
            Textarea::make('description')
                ->label('الوصف (عربي)')
                ->rows(3)
                ->columnSpanFull(),
            Textarea::make('description_en')
                ->label('الوصف (English)')
                ->rows(3)
                ->columnSpanFull(),
            FileUpload::make('image')
                ->label('صورة القسم')
                ->image()
                ->disk('public')
                ->directory('shop/categories')
                ->columnSpanFull(),
            TextInput::make('sort_order')
                ->label('الترتيب')
                ->numeric()
                ->default(0)
                ->required(),
            Toggle::make('is_active')
                ->label('ظاهر في التطبيق')
                ->default(true),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                ImageColumn::make('image')
                    ->label('صورة')
                    ->disk('public')
                    ->circular(),
                TextColumn::make('name')
                    ->label('القسم')
                    ->description(fn (ShopCategory $record): ?string => $record->name_en)
                    ->searchable(['name', 'name_en'])
                    ->sortable(),
                TextColumn::make('products_count')
                    ->counts('products')
                    ->label('المنتجات'),
                TextColumn::make('sort_order')
                    ->label('الترتيب')
                    ->sortable(),
                IconColumn::make('is_active')
                    ->label('ظاهر')
                    ->boolean(),
            ])
            ->defaultSort('sort_order')
            ->reorderable('sort_order')
            ->recordActions([
                EditAction::make(),
                DeleteAction::make(),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => ManageShopCategories::route('/'),
        ];
    }
}
