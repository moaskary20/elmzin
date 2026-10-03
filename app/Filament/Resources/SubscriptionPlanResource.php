<?php

namespace App\Filament\Resources;

use App\Filament\Resources\SubscriptionPlans\Pages\CreateSubscriptionPlan;
use App\Filament\Resources\SubscriptionPlans\Pages\EditSubscriptionPlan;
use App\Filament\Resources\SubscriptionPlans\Pages\ListSubscriptionPlans;
use App\Models\SubscriptionPlan;
use BackedEnum;
use Filament\Actions\EditAction;
use Filament\Forms\Components\Repeater;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Columns\ToggleColumn;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

class SubscriptionPlanResource extends Resource
{
    protected static ?string $model = SubscriptionPlan::class;

    protected static ?string $navigationLabel = 'باقات الاشتراك';

    protected static ?string $modelLabel = 'باقة';

    protected static ?string $pluralModelLabel = 'باقات الاشتراك';

    protected static string|\UnitEnum|null $navigationGroup = 'الاشتراكات';

    protected static ?string $recordTitleAttribute = 'name';

    protected static bool $hasTitleCaseModelLabel = false;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedRectangleStack;

    protected static ?int $navigationSort = 1;

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('بيانات الباقة')
                ->description('هذه البيانات تظهر للصالون في أول خطوة من التسجيل في تطبيق الموبايل.')
                ->schema([
                    TextInput::make('name')
                        ->label('اسم الباقة')
                        ->required()
                        ->maxLength(120),
                    TextInput::make('badge')
                        ->label('شارة مميزة')
                        ->placeholder('مثال: مجاناً لمدة سنة • الأكثر طلباً')
                        ->maxLength(60),
                    TextInput::make('tagline')
                        ->label('وصف مختصر')
                        ->placeholder('سطر واحد يظهر تحت اسم الباقة')
                        ->maxLength(255)
                        ->columnSpanFull(),
                    Toggle::make('is_active')
                        ->label('ظاهرة في التطبيق')
                        ->default(true),
                    Toggle::make('is_featured')
                        ->label('باقة مميزة (تظهر أولاً بإطار ذهبي)')
                        ->default(false),
                ])
                ->columns(2)
                ->columnSpanFull(),
            Section::make('السعر والمدة')
                ->schema([
                    TextInput::make('price')
                        ->label('السعر')
                        ->numeric()
                        ->required()
                        ->minValue(0)
                        ->default(0)
                        ->suffix('ج.م')
                        ->helperText('اكتب 0 لتظهر الباقة «مجاناً».'),
                    TextInput::make('duration_value')
                        ->label('المدة')
                        ->numeric()
                        ->required()
                        ->minValue(1)
                        ->default(1),
                    Select::make('duration_unit')
                        ->label('الوحدة')
                        ->options(SubscriptionPlan::UNITS)
                        ->required()
                        ->default('year')
                        ->selectablePlaceholder(false),
                ])
                ->columns(3)
                ->columnSpanFull(),
            Section::make('مميزات الباقة')
                ->schema([
                    Repeater::make('features')
                        ->label('المميزات')
                        ->simple(
                            TextInput::make('text')
                                ->label('الميزة')
                                ->hiddenLabel()
                                ->placeholder('مثال: ظهور مميز في الصفحة الرئيسية')
                                ->required()
                                ->maxLength(160),
                        )
                        ->addActionLabel('إضافة ميزة')
                        ->reorderable()
                        ->defaultItems(1)
                        ->columnSpanFull(),
                ])
                ->columnSpanFull(),
            Section::make('قوانين الاشتراك')
                ->description('يوافق عليها الصالون قبل إتمام التسجيل.')
                ->schema([
                    Textarea::make('terms')
                        ->label('القوانين')
                        ->rows(7)
                        ->helperText('اكتب كل قانون في سطر مستقل، وسيظهر كبند مرقّم في التطبيق.')
                        ->columnSpanFull(),
                    TextInput::make('max_services')
                        ->label('الحد الأقصى للخدمات')
                        ->numeric()
                        ->minValue(1)
                        ->placeholder('بلا حدود'),
                    TextInput::make('max_specialists')
                        ->label('الحد الأقصى للأخصائيين')
                        ->numeric()
                        ->minValue(1)
                        ->placeholder('بلا حدود'),
                ])
                ->columns(2)
                ->columnSpanFull(),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('name')
                    ->label('الباقة')
                    ->description(fn (SubscriptionPlan $record): ?string => $record->tagline)
                    ->searchable()
                    ->weight('bold'),
                TextColumn::make('badge')
                    ->label('الشارة')
                    ->badge()
                    ->color('warning')
                    ->placeholder('—'),
                TextColumn::make('price')
                    ->label('السعر')
                    ->formatStateUsing(fn (SubscriptionPlan $record): string => $record->priceLabel())
                    ->badge()
                    ->color(fn (SubscriptionPlan $record): string => $record->isFree() ? 'success' : 'gray'),
                TextColumn::make('duration_value')
                    ->label('المدة')
                    ->formatStateUsing(fn (SubscriptionPlan $record): string => $record->durationLabel()),
                TextColumn::make('active_subscriptions_count')
                    ->label('صالونات مشتركة حالياً')
                    ->alignCenter(),
                IconColumn::make('is_featured')
                    ->label('مميزة')
                    ->boolean(),
                ToggleColumn::make('is_active')
                    ->label('ظاهرة'),
            ])
            ->reorderable('sort_order')
            ->defaultSort('sort_order')
            ->recordActions([
                EditAction::make(),
            ]);
    }

    public static function getEloquentQuery(): Builder
    {
        return parent::getEloquentQuery()->withCount([
            'subscriptions as active_subscriptions_count' => fn (Builder $query) => $query->current(),
        ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => ListSubscriptionPlans::route('/'),
            'create' => CreateSubscriptionPlan::route('/create'),
            'edit' => EditSubscriptionPlan::route('/{record}/edit'),
        ];
    }
}
