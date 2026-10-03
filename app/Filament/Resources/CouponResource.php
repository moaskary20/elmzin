<?php

namespace App\Filament\Resources;

use App\Enums\CouponType;
use App\Filament\Resources\Coupons\Pages\CreateCoupon;
use App\Filament\Resources\Coupons\Pages\EditCoupon;
use App\Filament\Resources\Coupons\Pages\ListCoupons;
use App\Filament\Resources\Coupons\RelationManagers\RedemptionsRelationManager;
use App\Models\Coupon;
use BackedEnum;
use Filament\Actions\BulkActionGroup;
use Filament\Actions\DeleteBulkAction;
use Filament\Actions\EditAction;
use Filament\Forms\Components\CheckboxList;
use Filament\Forms\Components\DateTimePicker;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Components\Utilities\Get;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

class CouponResource extends Resource
{
    protected static ?string $model = Coupon::class;

    protected static ?string $navigationLabel = 'الكوبونات';

    protected static ?string $modelLabel = 'كوبون';

    protected static ?string $pluralModelLabel = 'الكوبونات';

    protected static string|\UnitEnum|null $navigationGroup = 'العروض';

    protected static ?string $recordTitleAttribute = 'code';

    protected static bool $hasTitleCaseModelLabel = false;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedTicket;

    protected static ?int $navigationSort = 1;

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('بيانات الكوبون')
                ->schema([
                    TextInput::make('title')
                        ->label('اسم العرض')
                        ->required()
                        ->maxLength(255),
                    TextInput::make('code')
                        ->label('الرمز')
                        ->required()
                        ->unique(ignoreRecord: true)
                        ->maxLength(40)
                        ->extraInputAttributes(['style' => 'text-transform: uppercase'])
                        ->dehydrateStateUsing(fn (?string $state): string => strtoupper(trim((string) $state)))
                        ->helperText('مثال: WELCOME20'),
                    Textarea::make('description')
                        ->label('الوصف')
                        ->rows(2)
                        ->columnSpanFull(),
                    Toggle::make('is_active')
                        ->label('مفعّل')
                        ->default(true),
                ])
                ->columns(2)
                ->columnSpanFull(),
            Section::make('قيمة الخصم')
                ->schema([
                    Select::make('type')
                        ->label('نوع الخصم')
                        ->options(CouponType::class)
                        ->required()
                        ->native(false)
                        ->live()
                        ->default(CouponType::Percent),
                    TextInput::make('value')
                        ->label('القيمة')
                        ->numeric()
                        ->required()
                        ->minValue(0)
                        ->maxValue(fn (Get $get): ?int => ($get('type') === CouponType::Percent->value || $get('type') === CouponType::Percent) ? 100 : null)
                        ->suffix(fn (Get $get): string => ($get('type') === CouponType::Percent->value || $get('type') === CouponType::Percent) ? '٪' : 'ج.م'),
                    TextInput::make('min_amount')
                        ->label('الحد الأدنى للطلب')
                        ->numeric()
                        ->default(0)
                        ->minValue(0)
                        ->suffix('ج.م'),
                    TextInput::make('max_discount')
                        ->label('سقف الخصم')
                        ->numeric()
                        ->minValue(0)
                        ->suffix('ج.م')
                        ->visible(fn (Get $get): bool => $get('type') === CouponType::Percent->value || $get('type') === CouponType::Percent)
                        ->helperText('اختياري. يحد أقصى مبلغ الخصم عندما يكون النوع نسبة.'),
                ])
                ->columns(2)
                ->columnSpanFull(),
            Section::make('حدود الاستخدام')
                ->schema([
                    TextInput::make('usage_limit')
                        ->label('حد الاستخدام الكلي')
                        ->numeric()
                        ->minValue(1)
                        ->helperText('اتركه فارغاً لعدد غير محدود.'),
                    TextInput::make('usage_limit_per_user')
                        ->label('حد كل مستخدم')
                        ->numeric()
                        ->minValue(1)
                        ->helperText('اتركه فارغاً إن لم يُقيَّد لكل مستخدم.'),
                    DateTimePicker::make('starts_at')
                        ->label('يبدأ في')
                        ->native(false)
                        ->seconds(false),
                    DateTimePicker::make('ends_at')
                        ->label('ينتهي في')
                        ->native(false)
                        ->seconds(false),
                    Toggle::make('first_booking_only')
                        ->label('لأول حجز فقط')
                        ->default(false),
                ])
                ->columns(2)
                ->columnSpanFull(),
            Section::make('الصالونات')
                ->description('إن لم تختر صالوناً يسري الكوبون على كل الصالونات.')
                ->schema([
                    CheckboxList::make('salons')
                        ->label('صالونات محددة')
                        ->relationship('salons', 'name')
                        ->columns(2)
                        ->columnSpanFull(),
                ])
                ->columnSpanFull(),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('code')
                    ->label('الرمز')
                    ->searchable(),
                TextColumn::make('title')
                    ->label('العرض')
                    ->searchable(),
                TextColumn::make('type')
                    ->label('النوع')
                    ->badge(),
                TextColumn::make('value')
                    ->label('القيمة')
                    ->formatStateUsing(fn ($state, Coupon $record): string => $record->type === CouponType::Percent
                        ? $state.'٪'
                        : $state.' ج.م'),
                TextColumn::make('redemptions_count')
                    ->label('الاستخدام')
                    ->formatStateUsing(fn ($state, Coupon $record): string => $state.' / '.($record->usage_limit ?? '∞')),
                TextColumn::make('ends_at')
                    ->label('ينتهي')
                    ->dateTime('Y-m-d H:i')
                    ->placeholder('مفتوح'),
                IconColumn::make('is_active')
                    ->label('مفعّل')
                    ->boolean(),
            ])
            ->defaultSort('id', 'desc')
            ->filters([
                SelectFilter::make('type')
                    ->label('النوع')
                    ->options(CouponType::class),
                SelectFilter::make('is_active')
                    ->label('الحالة')
                    ->options([
                        1 => 'مفعّل',
                        0 => 'متوقف',
                    ]),
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

    public static function getEloquentQuery(): Builder
    {
        return parent::getEloquentQuery()->withCount('redemptions');
    }

    public static function getRelations(): array
    {
        return [
            'redemptions' => RedemptionsRelationManager::class,
        ];
    }

    public static function getPages(): array
    {
        return [
            'index' => ListCoupons::route('/'),
            'create' => CreateCoupon::route('/create'),
            'edit' => EditCoupon::route('/{record}/edit'),
        ];
    }
}
