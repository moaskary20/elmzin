<?php

namespace App\Filament\Resources;

use App\Filament\Resources\SupportOptions\Pages\CreateSupportOption;
use App\Filament\Resources\SupportOptions\Pages\EditSupportOption;
use App\Filament\Resources\SupportOptions\Pages\ListSupportOptions;
use App\Models\SupportOption;
use BackedEnum;
use Filament\Actions\EditAction;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Columns\ToggleColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;

class SupportOptionResource extends Resource
{
    protected static ?string $model = SupportOption::class;

    protected static ?string $navigationLabel = 'خيارات الدعم';

    protected static ?string $modelLabel = 'خيار';

    protected static ?string $pluralModelLabel = 'خيارات مراسلة الدعم';

    protected static bool $hasTitleCaseModelLabel = false;

    protected static string|\UnitEnum|null $navigationGroup = 'تطبيق الموبايل';

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedListBullet;

    protected static ?int $navigationSort = 4;

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('خيار القائمة')
                ->description('يظهر في قوائم مراسلة الدعم داخل التطبيق. فعّل «أخرى» لفتح مربع كتابة عند اختياره.')
                ->schema([
                    Select::make('field')
                        ->label('القائمة')
                        ->options(SupportOption::FIELDS)
                        ->required()
                        ->native(false),
                    TextInput::make('label')
                        ->label('النص (عربي)')
                        ->required()
                        ->maxLength(120),
                    TextInput::make('label_en')
                        ->label('النص (EN)')
                        ->maxLength(120),
                    TextInput::make('sort_order')
                        ->label('الترتيب')
                        ->numeric()
                        ->default(0)
                        ->required(),
                    Toggle::make('is_other')
                        ->label('خيار «أخرى» (يفتح مربع كتابة)')
                        ->default(false),
                    Toggle::make('is_active')
                        ->label('ظاهر في التطبيق')
                        ->default(true),
                ])
                ->columns(2)
                ->columnSpanFull(),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('field')
                    ->label('القائمة')
                    ->formatStateUsing(fn (string $state): string => SupportOption::FIELDS[$state] ?? $state)
                    ->badge()
                    ->color(fn (string $state): string => $state === 'topic' ? 'warning' : 'info'),
                TextColumn::make('label')
                    ->label('النص')
                    ->searchable()
                    ->description(fn (SupportOption $record): ?string => $record->label_en),
                IconColumn::make('is_other')
                    ->label('أخرى')
                    ->boolean(),
                TextColumn::make('sort_order')
                    ->label('ترتيب')
                    ->sortable(),
                ToggleColumn::make('is_active')
                    ->label('ظاهر'),
            ])
            ->defaultSort('sort_order')
            ->reorderable('sort_order')
            ->filters([
                SelectFilter::make('field')
                    ->label('القائمة')
                    ->options(SupportOption::FIELDS),
            ])
            ->recordActions([
                EditAction::make(),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => ListSupportOptions::route('/'),
            'create' => CreateSupportOption::route('/create'),
            'edit' => EditSupportOption::route('/{record}/edit'),
        ];
    }
}
