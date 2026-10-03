<?php

namespace App\Filament\Resources;

use App\Filament\Resources\Reviews\Pages\CreateReview;
use App\Filament\Resources\Reviews\Pages\EditReview;
use App\Filament\Resources\Reviews\Pages\ListReviews;
use App\Models\Review;
use App\Models\Specialist;
use BackedEnum;
use Filament\Actions\BulkActionGroup;
use Filament\Actions\DeleteBulkAction;
use Filament\Actions\EditAction;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Components\Utilities\Get;
use Filament\Schemas\Components\Utilities\Set;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;

class ReviewResource extends Resource
{
    protected static ?string $model = Review::class;

    protected static ?string $navigationLabel = 'التقييمات';

    protected static ?string $modelLabel = 'تقييم';

    protected static ?string $pluralModelLabel = 'التقييمات';

    protected static bool $hasTitleCaseModelLabel = false;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedStar;

    protected static ?int $navigationSort = 5;

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('التقييم')
                ->schema([
                    Select::make('salon_id')
                        ->label('الصالون')
                        ->relationship('salon', 'name')
                        ->searchable()
                        ->preload()
                        ->live()
                        ->required()
                        ->native(false)
                        ->afterStateUpdated(fn (Set $set) => $set('specialist_id', null)),
                    Select::make('specialist_id')
                        ->label('الأخصائي')
                        ->options(fn (Get $get): array => Specialist::query()
                            ->where('salon_id', $get('salon_id'))
                            ->orderBy('name')
                            ->pluck('name', 'id')
                            ->all())
                        ->searchable()
                        ->native(false)
                        ->disabled(fn (Get $get): bool => blank($get('salon_id'))),
                    TextInput::make('customer_name')
                        ->label('اسم العميل')
                        ->required(),
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
                ])
                ->columns(2)
                ->columnSpanFull(),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('salon.name')
                    ->label('الصالون')
                    ->searchable(),
                TextColumn::make('specialist.name')
                    ->label('الأخصائي')
                    ->placeholder('—'),
                TextColumn::make('customer_name')
                    ->label('العميل')
                    ->searchable(),
                TextColumn::make('rating')
                    ->label('التقييم')
                    ->formatStateUsing(fn ($state): string => number_format((float) $state, 0).' ★'),
                TextColumn::make('comment')
                    ->label('التعليق')
                    ->limit(40),
                IconColumn::make('is_visible')
                    ->label('ظاهر')
                    ->boolean(),
            ])
            ->defaultSort('created_at', 'desc')
            ->filters([
                SelectFilter::make('salon_id')
                    ->label('الصالون')
                    ->relationship('salon', 'name'),
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
            'index' => ListReviews::route('/'),
            'create' => CreateReview::route('/create'),
            'edit' => EditReview::route('/{record}/edit'),
        ];
    }
}
