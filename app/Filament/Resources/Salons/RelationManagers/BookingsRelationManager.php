<?php

namespace App\Filament\Resources\Salons\RelationManagers;

use App\Enums\BookingStatus;
use App\Models\Salon;
use Carbon\Carbon;
use Filament\Actions\CreateAction;
use Filament\Actions\DeleteAction;
use Filament\Actions\EditAction;
use Filament\Forms\Components\DatePicker;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Resources\RelationManagers\RelationManager;
use Filament\Schemas\Components\Utilities\Get;
use Filament\Schemas\Components\Utilities\Set;
use Filament\Schemas\Schema;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;

class BookingsRelationManager extends RelationManager
{
    protected static string $relationship = 'bookings';

    protected static ?string $title = 'المواعيد';

    protected static ?string $modelLabel = 'موعد';

    protected static ?string $pluralModelLabel = 'مواعيد';

    protected static bool $isLazy = false;

    public function form(Schema $schema): Schema
    {
        return $schema->components([
            Select::make('specialist_id')
                ->label('الأخصائي')
                ->options(fn (): array => $this->salon()->specialists()
                    ->where('is_active', true)
                    ->orderBy('name')
                    ->pluck('name', 'id')
                    ->all())
                ->searchable()
                ->required()
                ->native(false)
                ->live()
                ->afterStateUpdated(fn (Set $set) => $set('booked_time', null)),
            Select::make('service_id')
                ->label('الخدمة')
                ->options(fn (): array => $this->salon()->services()
                    ->where('is_active', true)
                    ->orderBy('name')
                    ->pluck('name', 'id')
                    ->all())
                ->searchable()
                ->required()
                ->native(false),
            DatePicker::make('booked_on')
                ->label('اليوم')
                ->required()
                ->native(false)
                ->live()
                ->minDate(fn (string $operation) => $operation === 'create' ? now()->startOfDay() : null)
                ->afterStateUpdated(fn (Set $set) => $set('booked_time', null)),
            Select::make('booked_time')
                ->label('الوقت')
                ->options(fn (Get $get): array => $this->timeOptions($get('booked_on')))
                ->required()
                ->native(false)
                ->disabled(fn (Get $get): bool => blank($get('booked_on'))),
            Select::make('status')
                ->label('الحالة')
                ->options(BookingStatus::class)
                ->default(BookingStatus::Pending)
                ->required()
                ->native(false),
            TextInput::make('customer_name')
                ->label('اسم العميل')
                ->required(),
            TextInput::make('customer_phone')
                ->label('هاتف العميل')
                ->tel()
                ->required(),
            Textarea::make('notes')
                ->label('ملاحظات')
                ->rows(2)
                ->columnSpanFull(),
        ]);
    }

    public function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('booked_on')
                    ->label('اليوم')
                    ->date('Y-m-d')
                    ->sortable(),
                TextColumn::make('booked_time')
                    ->label('الوقت'),
                TextColumn::make('customer_name')
                    ->label('العميل')
                    ->searchable(),
                TextColumn::make('service.name')
                    ->label('الخدمة'),
                TextColumn::make('specialist.name')
                    ->label('الأخصائي'),
                TextColumn::make('status')
                    ->label('الحالة')
                    ->badge(),
                TextColumn::make('total')
                    ->label('الإجمالي')
                    ->suffix(' ج.م'),
            ])
            ->defaultSort('booked_on', 'desc')
            ->headerActions([
                CreateAction::make()->label('إضافة موعد'),
            ])
            ->recordActions([
                EditAction::make(),
                DeleteAction::make(),
            ]);
    }

    private function salon(): Salon
    {
        /** @var Salon $salon */
        $salon = $this->getOwnerRecord();

        return $salon;
    }

    /**
     * @return array<string, string>
     */
    private function timeOptions(mixed $date): array
    {
        if (blank($date)) {
            return [];
        }

        $day = Carbon::parse($date)->dayOfWeek;
        $hour = $this->salon()->workingHours()->where('day_of_week', $day)->first();

        if (! $hour || $hour->is_closed || ! $hour->opens_at || ! $hour->closes_at) {
            return [];
        }

        $cursor = Carbon::parse($hour->opens_at);
        $end = Carbon::parse($hour->closes_at);
        $options = [];

        while ($cursor->copy()->addMinutes(30)->lte($end)) {
            $label = $cursor->format('H:i');
            $options[$label] = $label;
            $cursor->addMinutes(30);
        }

        return $options;
    }
}
