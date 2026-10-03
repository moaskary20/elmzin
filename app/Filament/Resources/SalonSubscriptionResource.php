<?php

namespace App\Filament\Resources;

use App\Filament\Resources\SalonSubscriptions\Pages\CreateSalonSubscription;
use App\Filament\Resources\SalonSubscriptions\Pages\EditSalonSubscription;
use App\Filament\Resources\SalonSubscriptions\Pages\ListSalonSubscriptions;
use App\Models\SalonSubscription;
use App\Models\SubscriptionPlan;
use App\Services\SubscriptionService;
use BackedEnum;
use Carbon\Carbon;
use Filament\Actions\Action;
use Filament\Actions\EditAction;
use Filament\Forms\Components\DateTimePicker;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Notifications\Notification;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Components\Utilities\Get;
use Filament\Schemas\Components\Utilities\Set;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

class SalonSubscriptionResource extends Resource
{
    protected static ?string $model = SalonSubscription::class;

    protected static ?string $navigationLabel = 'اشتراكات الصالونات';

    protected static ?string $modelLabel = 'اشتراك';

    protected static ?string $pluralModelLabel = 'اشتراكات الصالونات';

    protected static string|\UnitEnum|null $navigationGroup = 'الاشتراكات';

    protected static bool $hasTitleCaseModelLabel = false;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedCreditCard;

    protected static ?int $navigationSort = 2;

    public static function form(Schema $schema): Schema
    {
        $fillFromPlan = function (Get $get, Set $set): void {
            $plan = SubscriptionPlan::query()->find($get('subscription_plan_id'));
            if (! $plan) {
                return;
            }
            $start = Carbon::parse($get('starts_at') ?: now());
            $set('plan_name', $plan->name);
            $set('price', (float) $plan->price);
            $set('ends_at', $plan->endsFrom($start)->format('Y-m-d H:i:s'));
        };

        return $schema->components([
            Section::make('الاشتراك')
                ->schema([
                    Select::make('salon_id')
                        ->label('الصالون')
                        ->relationship('salon', 'name')
                        ->searchable()
                        ->preload()
                        ->required(),
                    Select::make('subscription_plan_id')
                        ->label('الباقة')
                        ->relationship('plan', 'name')
                        ->preload()
                        ->live()
                        ->afterStateUpdated($fillFromPlan)
                        ->required(),
                    TextInput::make('plan_name')
                        ->label('اسم الباقة وقت الاشتراك')
                        ->required()
                        ->maxLength(120),
                    TextInput::make('price')
                        ->label('المبلغ')
                        ->numeric()
                        ->minValue(0)
                        ->default(0)
                        ->suffix('ج.م'),
                    DateTimePicker::make('starts_at')
                        ->label('يبدأ في')
                        ->native(false)
                        ->seconds(false)
                        ->default(now())
                        ->live()
                        ->afterStateUpdated($fillFromPlan)
                        ->required(),
                    DateTimePicker::make('ends_at')
                        ->label('ينتهي في')
                        ->native(false)
                        ->seconds(false)
                        ->after('starts_at')
                        ->required(),
                    Select::make('status')
                        ->label('الحالة')
                        ->options(SalonSubscription::STATUSES)
                        ->default('active')
                        ->selectablePlaceholder(false)
                        ->required(),
                    Textarea::make('notes')
                        ->label('ملاحظات')
                        ->rows(2)
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
                    ->searchable()
                    ->weight('bold'),
                TextColumn::make('plan_name')
                    ->label('الباقة')
                    ->badge()
                    ->color('warning'),
                TextColumn::make('price')
                    ->label('المبلغ')
                    ->formatStateUsing(fn ($state): string => (float) $state <= 0 ? 'مجاناً' : number_format((float) $state).' ج.م'),
                TextColumn::make('starts_at')
                    ->label('البداية')
                    ->date('Y-m-d')
                    ->sortable(),
                TextColumn::make('ends_at')
                    ->label('النهاية')
                    ->date('Y-m-d')
                    ->sortable()
                    ->description(fn (SalonSubscription $record): ?string => $record->state() === 'active'
                        ? 'متبقٍ '.$record->daysLeft().' يوم'
                        : null),
                TextColumn::make('status')
                    ->label('الحالة')
                    ->badge()
                    ->state(fn (SalonSubscription $record): string => $record->stateLabel())
                    ->color(fn (SalonSubscription $record): string => match ($record->state()) {
                        'active' => $record->daysLeft() <= 30 ? 'warning' : 'success',
                        'expired' => 'gray',
                        default => 'danger',
                    }),
                TextColumn::make('terms_accepted_at')
                    ->label('وافق على القوانين')
                    ->dateTime('Y-m-d')
                    ->placeholder('—')
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->defaultSort('id', 'desc')
            ->filters([
                SelectFilter::make('state')
                    ->label('الحالة')
                    ->options([
                        'active' => 'فعّال',
                        'ending' => 'ينتهي خلال 30 يوماً',
                        'expired' => 'منتهي',
                        'cancelled' => 'ملغي',
                    ])
                    ->query(fn (Builder $query, array $data): Builder => match ($data['value'] ?? null) {
                        'active' => $query->current(),
                        'ending' => $query->current()->where('ends_at', '<=', now()->addDays(30)),
                        'expired' => $query->where('status', '!=', 'cancelled')->where('ends_at', '<=', now()),
                        'cancelled' => $query->where('status', 'cancelled'),
                        default => $query,
                    }),
                SelectFilter::make('subscription_plan_id')
                    ->label('الباقة')
                    ->relationship('plan', 'name'),
            ])
            ->recordActions([
                Action::make('renew')
                    ->label('تجديد')
                    ->icon(Heroicon::OutlinedArrowPath)
                    ->color('success')
                    ->schema([
                        Select::make('plan_id')
                            ->label('الباقة')
                            ->options(fn () => SubscriptionPlan::query()->available()->pluck('name', 'id'))
                            ->default(fn (SalonSubscription $record) => $record->subscription_plan_id)
                            ->required(),
                    ])
                    ->action(function (SalonSubscription $record, array $data): void {
                        $plan = SubscriptionPlan::query()->findOrFail($data['plan_id']);
                        $next = app(SubscriptionService::class)->renew($record->salon, $plan);

                        Notification::make()
                            ->title('تم تجديد الاشتراك حتى '.$next->ends_at->format('Y-m-d'))
                            ->success()
                            ->send();
                    }),
                Action::make('cancel')
                    ->label('إلغاء')
                    ->icon(Heroicon::OutlinedXCircle)
                    ->color('danger')
                    ->requiresConfirmation()
                    ->visible(fn (SalonSubscription $record): bool => $record->state() === 'active')
                    ->action(fn (SalonSubscription $record) => $record->update(['status' => 'cancelled'])),
                EditAction::make(),
            ]);
    }

    public static function getEloquentQuery(): Builder
    {
        return parent::getEloquentQuery()->with(['salon', 'plan']);
    }

    public static function getPages(): array
    {
        return [
            'index' => ListSalonSubscriptions::route('/'),
            'create' => CreateSalonSubscription::route('/create'),
            'edit' => EditSalonSubscription::route('/{record}/edit'),
        ];
    }
}
