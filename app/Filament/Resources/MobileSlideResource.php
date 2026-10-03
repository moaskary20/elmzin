<?php

namespace App\Filament\Resources;

use App\Filament\Resources\MobileSlides\Pages\CreateMobileSlide;
use App\Filament\Resources\MobileSlides\Pages\EditMobileSlide;
use App\Filament\Resources\MobileSlides\Pages\ListMobileSlides;
use App\Models\MobileSlide;
use BackedEnum;
use Filament\Actions\BulkActionGroup;
use Filament\Actions\DeleteBulkAction;
use Filament\Actions\EditAction;
use Filament\Forms\Components\FileUpload;
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
use Filament\Tables\Table;

class MobileSlideResource extends Resource
{
    protected static ?string $model = MobileSlide::class;

    protected static ?string $navigationLabel = 'السلايدر';

    protected static ?string $modelLabel = 'شريحة';

    protected static ?string $pluralModelLabel = 'شرائح السلايدر';

    protected static ?string $recordTitleAttribute = 'title';

    protected static bool $hasTitleCaseModelLabel = false;

    protected static string|\UnitEnum|null $navigationGroup = 'تطبيق الموبايل';

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedPhoto;

    protected static ?int $navigationSort = 1;

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('شريحة السلايدر')
                ->description('تظهر في أعلى الشاشة الرئيسية لتطبيق الموبايل.')
                ->schema([
                    FileUpload::make('image')
                        ->label('الصورة')
                        ->image()
                        ->disk('public')
                        ->directory('slides')
                        ->required()
                        ->columnSpanFull(),
                    TextInput::make('title')
                        ->label('العنوان')
                        ->required()
                        ->maxLength(255)
                        ->helperText('يظهر بخط كبير على الصورة.'),
                    Textarea::make('subtitle')
                        ->label('النص')
                        ->rows(3)
                        ->helperText('يظهر بخط صغير تحت العنوان.'),
                    TextInput::make('title_en')
                        ->label('العنوان بالإنجليزية')
                        ->maxLength(255),
                    Textarea::make('subtitle_en')
                        ->label('النص بالإنجليزية')
                        ->rows(3),
                    TextInput::make('sort_order')
                        ->label('الترتيب')
                        ->numeric()
                        ->default(0)
                        ->required(),
                    Toggle::make('is_active')
                        ->label('ظاهرة في التطبيق')
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
                ImageColumn::make('image')
                    ->label('الصورة')
                    ->disk('public')
                    ->height(56),
                TextColumn::make('title')
                    ->label('العنوان')
                    ->searchable()
                    ->sortable(),
                TextColumn::make('subtitle')
                    ->label('النص')
                    ->limit(48)
                    ->toggleable(),
                TextColumn::make('sort_order')
                    ->label('الترتيب')
                    ->sortable(),
                IconColumn::make('is_active')
                    ->label('ظاهرة')
                    ->boolean(),
            ])
            ->defaultSort('sort_order')
            ->reorderable('sort_order')
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
            'index' => ListMobileSlides::route('/'),
            'create' => CreateMobileSlide::route('/create'),
            'edit' => EditMobileSlide::route('/{record}/edit'),
        ];
    }
}
