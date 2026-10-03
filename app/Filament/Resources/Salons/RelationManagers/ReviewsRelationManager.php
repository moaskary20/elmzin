<?php

namespace App\Filament\Resources\Salons\RelationManagers;

use Filament\Actions\CreateAction;
use Filament\Actions\DeleteAction;
use Filament\Actions\EditAction;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Resources\RelationManagers\RelationManager;
use Filament\Schemas\Schema;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;

class ReviewsRelationManager extends RelationManager
{
    protected static string $relationship = 'reviews';

    protected static ?string $title = 'التقييمات';

    protected static ?string $modelLabel = 'تقييم';

    protected static ?string $pluralModelLabel = 'تقييمات';

    protected static bool $isLazy = false;

    public function form(Schema $schema): Schema
    {
        return $schema->components([
            TextInput::make('customer_name')
                ->label('اسم العميل')
                ->required(),
            Select::make('specialist_id')
                ->label('الأخصائي')
                ->options(fn () => $this->getOwnerRecord()->specialists()->orderBy('name')->pluck('name', 'id'))
                ->searchable()
                ->native(false),
            Select::make('rating')
                ->label('التقييم')
                ->options([
                    5 => '5 — ممتاز',
                    4 => '4 — جيد جداً',
                    3 => '3 — جيد',
                    2 => '2 — مقبول',
                    1 => '1 — ضعيف',
                ])
                ->required()
                ->native(false),
            Toggle::make('is_visible')
                ->label('ظاهر للعملاء')
                ->default(true),
            Textarea::make('comment')
                ->label('التعليق')
                ->rows(3)
                ->columnSpanFull(),
        ]);
    }

    public function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('customer_name')
                    ->label('العميل'),
                TextColumn::make('specialist.name')
                    ->label('الأخصائي')
                    ->placeholder('—'),
                TextColumn::make('rating')
                    ->label('التقييم')
                    ->formatStateUsing(fn ($state): string => str_repeat('★', (int) $state)),
                TextColumn::make('comment')
                    ->label('التعليق')
                    ->limit(40),
                IconColumn::make('is_visible')
                    ->label('ظاهر')
                    ->boolean(),
            ])
            ->headerActions([
                CreateAction::make()->label('إضافة تقييم'),
            ])
            ->recordActions([
                EditAction::make(),
                DeleteAction::make(),
            ]);
    }
}
