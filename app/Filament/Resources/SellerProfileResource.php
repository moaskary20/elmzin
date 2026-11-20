<?php

namespace App\Filament\Resources;

use App\Enums\VerificationStatus;
use App\Filament\Resources\SellerProfiles\Pages\EditSellerProfile;
use App\Filament\Resources\SellerProfiles\Pages\ListSellerProfiles;
use App\Models\SellerProfile;
use BackedEnum;
use Filament\Actions\EditAction;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\ImageColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

class SellerProfileResource extends Resource
{
    protected static ?string $model = SellerProfile::class;

    protected static ?string $navigationLabel = 'البائعون';

    protected static ?string $modelLabel = 'بائع';

    protected static ?string $pluralModelLabel = 'البائعون';

    protected static bool $hasTitleCaseModelLabel = false;

    protected static string|\UnitEnum|null $navigationGroup = 'التسوق';

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedBuildingStorefront;

    protected static ?int $navigationSort = 4;

    public static function canCreate(): bool
    {
        return false;
    }

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('بيانات البائع')
                ->schema([
                    TextInput::make('user.name')
                        ->label('الاسم')
                        ->disabled()
                        ->dehydrated(false),
                    TextInput::make('user.phone')
                        ->label('الهاتف')
                        ->disabled()
                        ->dehydrated(false),
                    TextInput::make('user.email')
                        ->label('البريد')
                        ->disabled()
                        ->dehydrated(false),
                    TextInput::make('national_id')
                        ->label('رقم البطاقة')
                        ->maxLength(14),
                    Select::make('verification_status')
                        ->label('حالة التوثيق')
                        ->options(collect(VerificationStatus::cases())->mapWithKeys(
                            fn (VerificationStatus $status): array => [$status->value => $status->getLabel()],
                        ))
                        ->required()
                        ->native(false),
                    Toggle::make('is_active')
                        ->label('نشط')
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
                TextColumn::make('user.name')
                    ->label('البائع')
                    ->searchable()
                    ->description(fn (SellerProfile $record): string => $record->user?->phone ?? ''),
                TextColumn::make('national_id')
                    ->label('رقم البطاقة')
                    ->placeholder('—'),
                ImageColumn::make('commercial_register_image')
                    ->label('السجل التجاري')
                    ->disk('public')
                    ->height(40)
                    ->square(),
                TextColumn::make('verification_status')
                    ->label('التوثيق')
                    ->badge()
                    ->formatStateUsing(fn ($state): string => ($state instanceof VerificationStatus
                        ? $state->getLabel()
                        : (string) $state))
                    ->color(fn ($state): string => ($state instanceof VerificationStatus
                        ? $state->getColor()
                        : 'gray')),
                TextColumn::make('user.sellerSubscriptions.plan_name')
                    ->label('الباقة')
                    ->state(fn (SellerProfile $record): string => $record->user?->activeSellerSubscription()?->plan_name ?? '—'),
            ])
            ->defaultSort('id', 'desc')
            ->filters([
                SelectFilter::make('verification_status')
                    ->label('التوثيق')
                    ->options(collect(VerificationStatus::cases())->mapWithKeys(
                        fn (VerificationStatus $status): array => [$status->value => $status->getLabel()],
                    )),
            ])
            ->recordActions([
                EditAction::make(),
            ]);
    }

    public static function getEloquentQuery(): Builder
    {
        return parent::getEloquentQuery()->with(['user']);
    }

    public static function getPages(): array
    {
        return [
            'index' => ListSellerProfiles::route('/'),
            'edit' => EditSellerProfile::route('/{record}/edit'),
        ];
    }
}
