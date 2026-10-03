<?php

namespace App\Filament\Resources;

use App\Filament\Resources\AppPages\Pages\EditAppPage;
use App\Filament\Resources\AppPages\Pages\ListAppPages;
use App\Models\AppPage;
use BackedEnum;
use Filament\Actions\EditAction;
use Filament\Forms\Components\Repeater;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;

class AppPageResource extends Resource
{
    protected static ?string $model = AppPage::class;

    protected static ?string $navigationLabel = 'صفحات الإعدادات';

    protected static ?string $modelLabel = 'صفحة';

    protected static ?string $pluralModelLabel = 'صفحات الإعدادات';

    protected static ?string $recordTitleAttribute = 'title';

    protected static bool $hasTitleCaseModelLabel = false;

    protected static string|\UnitEnum|null $navigationGroup = 'تطبيق الموبايل';

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedLifebuoy;

    protected static ?int $navigationSort = 2;

    public static function canCreate(): bool
    {
        return false;
    }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('صفحة التطبيق')
                ->description('تظهر في الإعدادات: مركز المساعدة، الأسئلة الشائعة، أو سياسة الخصوصية.')
                ->schema([
                    TextInput::make('slug')
                        ->label('المعرّف')
                        ->disabled()
                        ->dehydrated(false),
                    Toggle::make('is_active')
                        ->label('ظاهرة في التطبيق')
                        ->default(true),
                    TextInput::make('title')
                        ->label('العنوان')
                        ->required()
                        ->maxLength(255),
                    TextInput::make('title_en')
                        ->label('العنوان بالإنجليزية')
                        ->maxLength(255),
                    Textarea::make('intro')
                        ->label('مقدمة')
                        ->rows(2),
                    Textarea::make('intro_en')
                        ->label('المقدمة بالإنجليزية')
                        ->rows(2),
                    Repeater::make('blocks')
                        ->label('الفقرات')
                        ->relationship()
                        ->orderColumn('sort_order')
                        ->schema([
                            TextInput::make('title')
                                ->label('العنوان')
                                ->required()
                                ->maxLength(255),
                            TextInput::make('title_en')
                                ->label('العنوان بالإنجليزية')
                                ->maxLength(255),
                            Textarea::make('body')
                                ->label('النص')
                                ->required()
                                ->rows(3)
                                ->columnSpanFull(),
                            Textarea::make('body_en')
                                ->label('النص بالإنجليزية')
                                ->rows(3)
                                ->columnSpanFull(),
                        ])
                        ->columns(2)
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
                TextColumn::make('title')
                    ->label('الصفحة')
                    ->searchable(),
                TextColumn::make('blocks_count')
                    ->counts('blocks')
                    ->label('الفقرات'),
                IconColumn::make('is_active')
                    ->label('ظاهرة')
                    ->boolean(),
            ])
            ->recordActions([
                EditAction::make(),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => ListAppPages::route('/'),
            'edit' => EditAppPage::route('/{record}/edit'),
        ];
    }
}
