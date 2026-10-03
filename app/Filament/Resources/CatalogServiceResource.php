<?php

namespace App\Filament\Resources;

use App\Filament\Resources\CatalogServices\Pages\ManageCatalogServices;
use App\Models\CatalogService;
use BackedEnum;
use Filament\Actions\DeleteAction;
use Filament\Actions\EditAction;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Utilities\Get;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Columns\ToggleColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use Illuminate\Validation\Rules\Unique;

class CatalogServiceResource extends Resource
{
    protected static ?string $model = CatalogService::class;

    protected static ?string $navigationLabel = 'الخدمات';

    protected static ?string $modelLabel = 'خدمة';

    protected static ?string $pluralModelLabel = 'الخدمات';

    protected static ?string $recordTitleAttribute = 'name';

    protected static bool $hasTitleCaseModelLabel = false;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedScissors;

    protected static ?int $navigationSort = 3;

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            Select::make('category_id')
                ->label('القسم')
                ->relationship('category', 'name')
                ->required()
                ->native(false)
                ->live(),
            TextInput::make('name')
                ->label('اسم الخدمة')
                ->required()
                ->maxLength(255)
                ->unique(
                    ignoreRecord: true,
                    modifyRuleUsing: fn (Unique $rule, Get $get): Unique => $rule->where('category_id', $get('category_id')),
                )
                ->validationMessages(['unique' => 'هذه الخدمة موجودة بالفعل في هذا القسم.']),
            Toggle::make('is_active')
                ->label('متاحة للصالونات')
                ->helperText('تظهر عند اشتراك الصالون وعند إضافة خدمة للصالون.')
                ->default(true)
                ->columnSpanFull(),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->description('يضيف المدير الخدمات لكل قسم، ويختار منها الصالون ويحدد سعره عند الاشتراك أو عند إضافة خدمة.')
            ->columns([
                TextColumn::make('name')
                    ->label('الخدمة')
                    ->searchable()
                    ->sortable(),
                TextColumn::make('category.name')
                    ->label('القسم')
                    ->badge()
                    ->sortable(),
                TextColumn::make('services_count')
                    ->label('عدد الصالونات')
                    ->counts('services')
                    ->sortable(),
                ToggleColumn::make('is_active')
                    ->label('متاحة'),
            ])
            ->defaultSort('category_id')
            ->filters([
                SelectFilter::make('category_id')
                    ->label('القسم')
                    ->relationship('category', 'name'),
            ])
            ->recordActions([
                EditAction::make(),
                DeleteAction::make()
                    ->modalDescription('لن تُحذف الخدمة من الصالونات التي أضافتها، لكنها لن تظهر للاختيار مجدداً.'),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => ManageCatalogServices::route('/'),
        ];
    }
}
