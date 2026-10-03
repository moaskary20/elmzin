<?php

namespace App\Filament\Resources\Salons\RelationManagers;

use App\Models\CatalogService;
use App\Models\Service;
use Filament\Actions\CreateAction;
use Filament\Actions\DeleteAction;
use Filament\Actions\EditAction;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Resources\RelationManagers\RelationManager;
use Filament\Schemas\Components\Utilities\Set;
use Filament\Schemas\Schema;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;

class ServicesRelationManager extends RelationManager
{
    protected static string $relationship = 'services';

    protected static ?string $title = 'الخدمات المقدمة';

    protected static ?string $modelLabel = 'خدمة';

    protected static ?string $pluralModelLabel = 'خدمات';

    protected static bool $isLazy = false;

    public function form(Schema $schema): Schema
    {
        return $schema->components([
            Select::make('catalog_service_id')
                ->label('الخدمة')
                ->helperText('من خدمات قسم الصالون في صفحة «الخدمات».')
                ->options(fn (): array => $this->availableCatalog())
                ->searchable()
                ->required()
                ->native(false)
                ->live()
                ->afterStateUpdated(function (?string $state, Set $set): void {
                    $minutes = CatalogService::query()->whereKey($state)->value('duration_minutes');

                    if ($minutes) {
                        $set('duration_minutes', $minutes);
                    }
                })
                ->visibleOn('create')
                ->columnSpanFull(),
            TextInput::make('name')
                ->label('الخدمة')
                ->disabled()
                ->dehydrated(false)
                ->visibleOn('edit')
                ->columnSpanFull(),
            TextInput::make('price')
                ->label('السعر')
                ->numeric()
                ->prefix('ج.م')
                ->required()
                ->minValue(1),
            TextInput::make('duration_minutes')
                ->label('المدة بالدقائق')
                ->numeric()
                ->required()
                ->minValue(5)
                ->default(30),
            Toggle::make('is_active')
                ->label('متاحة للحجز')
                ->default(true),
            Textarea::make('description')
                ->label('وصف مختصر')
                ->rows(2)
                ->columnSpanFull(),
        ]);
    }

    public function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('name')
                    ->label('الخدمة')
                    ->searchable(),
                TextColumn::make('price')
                    ->label('السعر')
                    ->formatStateUsing(fn ($state): string => number_format((float) $state, 0).' ج.م'),
                TextColumn::make('duration_minutes')
                    ->label('المدة')
                    ->suffix(' د'),
                IconColumn::make('is_active')
                    ->label('متاحة')
                    ->boolean(),
            ])
            ->headerActions([
                CreateAction::make()
                    ->label('إضافة خدمة')
                    ->mutateDataUsing(function (array $data): array {
                        $data['name'] = CatalogService::query()
                            ->whereKey($data['catalog_service_id'])
                            ->value('name');

                        return $data;
                    }),
            ])
            ->recordActions([
                EditAction::make(),
                DeleteAction::make(),
            ]);
    }

    /**
     * @return array<int, string>
     */
    private function availableCatalog(): array
    {
        $salon = $this->getOwnerRecord();
        $taken = $salon->services()->pluck('name')->all();

        return CatalogService::query()
            ->where('is_active', true)
            ->when($salon->category_id, fn ($query, $categoryId) => $query->where('category_id', $categoryId))
            ->whereNotIn('id', Service::query()->where('salon_id', $salon->getKey())->whereNotNull('catalog_service_id')->select('catalog_service_id'))
            ->whereNotIn('name', $taken)
            ->orderBy('sort_order')
            ->orderBy('id')
            ->pluck('name', 'id')
            ->all();
    }
}
