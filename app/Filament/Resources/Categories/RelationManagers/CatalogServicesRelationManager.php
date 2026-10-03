<?php

namespace App\Filament\Resources\Categories\RelationManagers;

use Filament\Actions\CreateAction;
use Filament\Actions\DeleteAction;
use Filament\Actions\EditAction;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Resources\RelationManagers\RelationManager;
use Filament\Schemas\Schema;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
use Illuminate\Validation\Rules\Unique;

class CatalogServicesRelationManager extends RelationManager
{
    protected static string $relationship = 'catalogServices';

    protected static ?string $title = 'خدمات القسم';

    protected static ?string $modelLabel = 'خدمة';

    protected static ?string $pluralModelLabel = 'خدمات';

    protected static bool $isLazy = false;

    public function form(Schema $schema): Schema
    {
        return $schema->components([
            TextInput::make('name')
                ->label('اسم الخدمة')
                ->required()
                ->maxLength(255)
                ->unique(
                    ignoreRecord: true,
                    modifyRuleUsing: fn (Unique $rule): Unique => $rule->where('category_id', $this->getOwnerRecord()->getKey()),
                )
                ->validationMessages(['unique' => 'هذه الخدمة موجودة بالفعل في هذا القسم.']),
            Toggle::make('is_active')
                ->label('متاحة للصالونات')
                ->default(true),
        ]);
    }

    public function table(Table $table): Table
    {
        return $table
            ->description('الخدمات التي يختار منها الصالون ويحدد سعرها عند الاشتراك أو عند إضافة خدمة.')
            ->columns([
                TextColumn::make('name')
                    ->label('الخدمة')
                    ->searchable(),
                TextColumn::make('services_count')
                    ->label('عدد الصالونات')
                    ->counts('services'),
                IconColumn::make('is_active')
                    ->label('متاحة')
                    ->boolean(),
            ])
            ->defaultSort('sort_order')
            ->reorderable('sort_order')
            ->headerActions([
                CreateAction::make()->label('إضافة خدمة'),
            ])
            ->recordActions([
                EditAction::make(),
                DeleteAction::make(),
            ]);
    }
}
