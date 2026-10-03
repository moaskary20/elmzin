<?php

namespace App\Filament\Resources;

use App\Enums\BookingStatus;
use App\Filament\Resources\Bookings\Pages\CreateBooking;
use App\Filament\Resources\Bookings\Pages\EditBooking;
use App\Filament\Resources\Bookings\Pages\ListBookings;
use App\Models\Booking;
use App\Models\Coupon;
use App\Models\Service;
use App\Models\Specialist;
use App\Models\TimeSlot;
use App\Models\User;
use App\Services\OfferService;
use BackedEnum;
use Carbon\Carbon;
use Filament\Actions\BulkActionGroup;
use Filament\Actions\DeleteBulkAction;
use Filament\Actions\EditAction;
use Filament\Forms\Components\DatePicker;
use Filament\Forms\Components\Placeholder;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
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
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\HtmlString;

class BookingResource extends Resource
{
    protected static ?string $model = Booking::class;

    protected static ?string $navigationLabel = 'الحجوزات';

    protected static ?string $modelLabel = 'حجز';

    protected static ?string $pluralModelLabel = 'الحجوزات';

    protected static bool $hasTitleCaseModelLabel = false;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedCalendarDays;

    protected static ?int $navigationSort = 4;

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('اختيار الموعد')
                ->description('يظهر الأخصائي والوقت من داخل الصالون المختار فقط.')
                ->schema([
                    Select::make('salon_id')
                        ->label('الصالون')
                        ->relationship('salon', 'name')
                        ->searchable()
                        ->preload()
                        ->live()
                        ->required()
                        ->native(false)
                        ->afterStateUpdated(function (Set $set): void {
                            $set('specialist_id', null);
                            $set('service_id', null);
                            $set('booked_time', null);
                        }),
                    Select::make('specialist_id')
                        ->label('اختر الأخصائي')
                        ->options(fn (Get $get): array => Specialist::query()
                            ->where('salon_id', $get('salon_id'))
                            ->where('is_active', true)
                            ->orderBy('name')
                            ->pluck('name', 'id')
                            ->all())
                        ->searchable()
                        ->live()
                        ->required()
                        ->native(false)
                        ->disabled(fn (Get $get): bool => blank($get('salon_id')))
                        ->afterStateUpdated(function (Set $set): void {
                            $set('service_id', null);
                            $set('booked_time', null);
                        }),
                    Select::make('service_id')
                        ->label('الخدمة')
                        ->options(function (Get $get): array {
                            $specialistId = $get('specialist_id');

                            if (blank($specialistId)) {
                                return Service::query()
                                    ->where('salon_id', $get('salon_id'))
                                    ->where('is_active', true)
                                    ->orderBy('name')
                                    ->pluck('name', 'id')
                                    ->all();
                            }

                            return Service::query()
                                ->where('is_active', true)
                                ->whereHas('specialists', fn (Builder $query) => $query->whereKey($specialistId))
                                ->orderBy('name')
                                ->pluck('name', 'id')
                                ->all();
                        })
                        ->searchable()
                        ->required()
                        ->native(false)
                        ->live()
                        ->disabled(fn (Get $get): bool => blank($get('salon_id'))),
                    DatePicker::make('booked_on')
                        ->label('التاريخ')
                        ->required()
                        ->native(false)
                        ->live()
                        ->minDate(fn (string $operation) => $operation === 'create' ? now()->startOfDay() : null)
                        ->afterStateUpdated(fn (Set $set) => $set('booked_time', null)),
                    Select::make('booked_time')
                        ->label('اختر الوقت')
                        ->options(fn (Get $get, ?Model $record): array => static::availableTimes($get, $record))
                        ->required()
                        ->native(false)
                        ->disabled(fn (Get $get): bool => blank($get('specialist_id')) || blank($get('booked_on')))
                        ->helperText('الأوقات تُؤخذ من جدول الأخصائي داخل الصالون، ويُخفى الوقت المحجوز.'),
                    Select::make('status')
                        ->label('حالة الحجز')
                        ->options(BookingStatus::class)
                        ->default(BookingStatus::Pending)
                        ->required()
                        ->native(false)
                        ->live(),
                ])
                ->columns(2)
                ->columnSpanFull(),
            Section::make('بيانات العميل')
                ->schema([
                    Select::make('user_id')
                        ->label('المستخدم')
                        ->options(fn (?Model $record): array => User::query()
                            ->customers()
                            ->where(function (Builder $query) use ($record): void {
                                $query->where('is_active', true);

                                if ($record?->user_id) {
                                    $query->orWhere('users.id', $record->user_id);
                                }
                            })
                            ->orderBy('name')
                            ->get()
                            ->mapWithKeys(fn (User $user): array => [
                                $user->id => $user->name.' — '.($user->phone ?: $user->email).' ('.$user->loyalty_points.' نقطة)',
                            ])
                            ->all())
                        ->searchable()
                        ->preload()
                        ->native(false)
                        ->live()
                        ->helperText('اختياري. الحجز بدون مستخدم لا يكتسب نقاطاً ولا يستخدم كوبون أول حجز.')
                        ->afterStateUpdated(function (Set $set, ?string $state): void {
                            if (blank($state)) {
                                return;
                            }

                            $user = User::query()->find($state);

                            if (! $user) {
                                return;
                            }

                            $set('customer_name', $user->name);
                            $set('customer_phone', $user->phone);
                            $set('points_redeemed', 0);
                        }),
                    TextInput::make('customer_name')
                        ->label('اسم العميل')
                        ->required(),
                    TextInput::make('customer_phone')
                        ->label('هاتف العميل')
                        ->tel()
                        ->required(),
                    Select::make('payment_method')
                        ->label('طريقة الدفع')
                        ->options(Booking::PAYMENT_LABELS)
                        ->default('cash')
                        ->required()
                        ->live(),
                    TextInput::make('card_last4')
                        ->label('آخر 4 أرقام من البطاقة')
                        ->maxLength(4)
                        ->visible(fn (Get $get): bool => $get('payment_method') === 'card'),
                    Textarea::make('notes')
                        ->label('ملاحظات')
                        ->rows(2)
                        ->columnSpanFull(),
                ])
                ->columns(2)
                ->columnSpanFull(),
            Section::make('الكوبون ونقاط الولاء')
                ->schema([
                    Select::make('coupon_id')
                        ->label('الكوبون')
                        ->options(fn (?Model $record): array => Coupon::query()
                            ->where(function (Builder $query) use ($record): void {
                                $query->where('is_active', true);

                                if ($record?->coupon_id) {
                                    $query->orWhere('coupons.id', $record->coupon_id);
                                }
                            })
                            ->orderBy('code')
                            ->get()
                            ->mapWithKeys(fn (Coupon $coupon): array => [$coupon->id => $coupon->code.' — '.$coupon->title])
                            ->all())
                        ->searchable()
                        ->preload()
                        ->native(false)
                        ->live(),
                    TextInput::make('points_redeemed')
                        ->label('نقاط للاستبدال')
                        ->numeric()
                        ->default(0)
                        ->minValue(0)
                        ->live()
                        ->disabled(fn (Get $get): bool => blank($get('user_id'))),
                    Placeholder::make('offer_preview')
                        ->label('ملخص السعر')
                        ->content(function (Get $get, ?Model $record): HtmlString {
                            $draft = new Booking([
                                'service_id' => $get('service_id'),
                                'salon_id' => $get('salon_id'),
                                'coupon_id' => $get('coupon_id'),
                                'user_id' => $get('user_id'),
                                'points_redeemed' => (int) ($get('points_redeemed') ?: 0),
                                'status' => $get('status') ?: BookingStatus::Pending,
                            ]);

                            if ($record) {
                                $draft->id = $record->getKey();
                                $draft->exists = true;
                            }

                            $quote = app(OfferService::class)->quote($draft);
                            $lines = [
                                'سعر الخدمة: '.number_format($quote['subtotal'], 2).' ج.م',
                                'خصم الكوبون: '.number_format($quote['coupon_discount'], 2).' ج.م',
                                'خصم النقاط: '.number_format($quote['points_discount'], 2).' ج.م',
                                'الإجمالي: '.number_format($quote['total'], 2).' ج.م',
                                'نقاط عند الاكتمال: '.$quote['earn_points'],
                            ];

                            if ($quote['coupon_error']) {
                                $lines[] = $quote['coupon_error'];
                            }

                            if ($quote['points_error']) {
                                $lines[] = $quote['points_error'];
                            }

                            return new HtmlString(nl2br(e(implode("\n", $lines))));
                        })
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
                TextColumn::make('customer_name')
                    ->label('العميل')
                    ->searchable(),
                TextColumn::make('salon.name')
                    ->label('الصالون')
                    ->searchable(),
                TextColumn::make('specialist.name')
                    ->label('الأخصائي'),
                TextColumn::make('service.name')
                    ->label('الخدمة'),
                TextColumn::make('booked_on')
                    ->label('التاريخ')
                    ->date('Y-m-d')
                    ->sortable(),
                TextColumn::make('booked_time')
                    ->label('الوقت'),
                TextColumn::make('coupon.code')
                    ->label('الكوبون')
                    ->placeholder('—'),
                TextColumn::make('total')
                    ->label('الإجمالي')
                    ->suffix(' ج.م'),
                TextColumn::make('payment_method')
                    ->label('الدفع')
                    ->badge()
                    ->formatStateUsing(fn (string $state, Booking $record): string => $record->paymentLabel())
                    ->color(fn (string $state): string => $state === 'card' ? 'info' : 'gray'),
                TextColumn::make('status')
                    ->label('الحالة')
                    ->badge(),
            ])
            ->defaultSort('booked_on', 'desc')
            ->filters([
                SelectFilter::make('salon_id')
                    ->label('الصالون')
                    ->relationship('salon', 'name'),
                SelectFilter::make('status')
                    ->label('الحالة')
                    ->options(BookingStatus::class),
                SelectFilter::make('payment_method')
                    ->label('طريقة الدفع')
                    ->options(Booking::PAYMENT_LABELS),
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
            'index' => ListBookings::route('/'),
            'create' => CreateBooking::route('/create'),
            'edit' => EditBooking::route('/{record}/edit'),
        ];
    }

    /**
     * @return array<string, string>
     */
    protected static function availableTimes(Get $get, ?Model $record): array
    {
        $specialistId = $get('specialist_id');
        $date = $get('booked_on');

        if (blank($specialistId) || blank($date)) {
            return [];
        }

        $day = Carbon::parse($date)->dayOfWeek;
        $dateString = Carbon::parse($date)->toDateString();

        $taken = Booking::query()
            ->where('specialist_id', $specialistId)
            ->whereDate('booked_on', $dateString)
            ->when($record, fn (Builder $query) => $query->whereKeyNot($record->getKey()))
            ->where('status', '!=', BookingStatus::Cancelled->value)
            ->pluck('booked_time')
            ->all();

        return TimeSlot::query()
            ->where('specialist_id', $specialistId)
            ->where('day_of_week', $day)
            ->where('is_active', true)
            ->orderBy('starts_at')
            ->get()
            ->reject(fn (TimeSlot $slot): bool => in_array($slot->clock('starts_at'), $taken, true))
            ->mapWithKeys(fn (TimeSlot $slot): array => [$slot->clock('starts_at') => $slot->label])
            ->all();
    }
}
