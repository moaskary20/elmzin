<?php

namespace App\Filament\Resources\Salons\RelationManagers;

use App\Enums\Weekday;
use Filament\Actions\CreateAction;
use Filament\Actions\DeleteAction;
use Filament\Actions\EditAction;
use Filament\Forms\Components\CheckboxList;
use Filament\Forms\Components\Repeater;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\TimePicker;
use Filament\Forms\Components\Toggle;
use Filament\Resources\RelationManagers\RelationManager;
use Filament\Schemas\Schema;
use Filament\Support\Enums\Width;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

class SpecialistsRelationManager extends RelationManager
{
    protected static string $relationship = 'specialists';

    protected static ?string $title = 'الأخصائيون';

    protected static ?string $modelLabel = 'أخصائي';

    protected static ?string $pluralModelLabel = 'أخصائيين';

    protected static bool $isLazy = false;

    public function form(Schema $schema): Schema
    {
        return $schema->components([
            TextInput::make('name')
                ->label('اسم الأخصائي')
                ->required()
                ->maxLength(255),
            TextInput::make('title')
                ->label('المسمّى')
                ->placeholder('حلاق، أخصائية تجميل، مصففة أطفال')
                ->maxLength(255),
            TextInput::make('phone')
                ->label('الهاتف')
                ->tel(),
            Toggle::make('is_active')
                ->label('يظهر للاختيار')
                ->default(true),
            Textarea::make('bio')
                ->label('نبذة')
                ->rows(2)
                ->columnSpanFull(),
            CheckboxList::make('services')
                ->label('الخدمات التي يقدّمها')
                ->relationship(
                    'services',
                    'name',
                    fn (Builder $query) => $query->where('salon_id', $this->getOwnerRecord()->getKey()),
                )
                ->columns(2)
                ->columnSpanFull()
                ->helperText('تظهر هنا خدمات هذا الصالون فقط.'),
            Repeater::make('timeSlots')
                ->label('الأوقات المتاحة')
                ->relationship('timeSlots')
                ->schema([
                    Select::make('day_of_week')
                        ->label('اليوم')
                        ->options(Weekday::class)
                        ->required()
                        ->native(false),
                    TimePicker::make('starts_at')
                        ->label('من')
                        ->seconds(false)
                        ->required(),
                    TimePicker::make('ends_at')
                        ->label('إلى')
                        ->seconds(false)
                        ->required(),
                    Toggle::make('is_active')
                        ->label('متاح')
                        ->default(true),
                ])
                ->columns(4)
                ->columnSpanFull()
                ->addActionLabel('إضافة وقت')
                ->defaultItems(0),
        ]);
    }

    public function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('name')
                    ->label('الأخصائي')
                    ->searchable(),
                TextColumn::make('title')
                    ->label('المسمّى'),
                TextColumn::make('services.name')
                    ->label('الخدمات')
                    ->badge(),
                TextColumn::make('time_slots_count')
                    ->counts('timeSlots')
                    ->label('الأوقات'),
                IconColumn::make('is_active')
                    ->label('ظاهر')
                    ->boolean(),
            ])
            ->headerActions([
                CreateAction::make()
                    ->label('إضافة أخصائي')
                    ->modalWidth(Width::FiveExtraLarge),
            ])
            ->recordActions([
                EditAction::make()->modalWidth(Width::FiveExtraLarge),
                DeleteAction::make(),
            ]);
    }
}
