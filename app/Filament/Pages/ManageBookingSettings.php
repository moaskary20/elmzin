<?php

namespace App\Filament\Pages;

use App\Models\BookingSetting;
use BackedEnum;
use Filament\Actions\Action;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Notifications\Notification;
use Filament\Pages\Page;
use Filament\Schemas\Components\Actions;
use Filament\Schemas\Components\EmbeddedSchema;
use Filament\Schemas\Components\Form;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;

class ManageBookingSettings extends Page
{
    protected static ?string $navigationLabel = 'إلغاء الحجوزات';

    protected static ?string $title = 'إعدادات إلغاء الحجوزات';

    protected static string|\UnitEnum|null $navigationGroup = 'الإعدادات';

    protected static ?string $slug = 'booking-settings';

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedNoSymbol;

    protected static ?int $navigationSort = 2;

    /**
     * @var array<string, mixed>|null
     */
    public ?array $data = [];

    public function mount(): void
    {
        $this->form->fill(BookingSetting::current()->attributesToArray());
    }

    public function getSubheading(): ?string
    {
        return 'بعد قبول الصالون للحجز، يُمنع الإلغاء إذا تبقّى أقل من الساعات المحددة قبل الموعد، وتظهر الرسالة داخل التطبيق.';
    }

    public function defaultForm(Schema $schema): Schema
    {
        return $schema->statePath('data');
    }

    public function form(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('إلغاء الصالون بعد القبول')
                ->description('ينطبق على الحجوزات المؤكدة فقط. الحجوزات بانتظار التأكيد يمكن إلغاؤها كالمعتاد.')
                ->schema([
                    Toggle::make('salon_cancel_lock_enabled')
                        ->label('تفعيل منع الإلغاء قبل الموعد')
                        ->helperText('عند التفعيل، يظهر للصالون رسالة عند محاولة الإلغاء داخل المدة المحددة.')
                        ->default(true),
                    TextInput::make('salon_cancel_hours_before')
                        ->label('عدد الساعات قبل الموعد')
                        ->numeric()
                        ->required()
                        ->minValue(0)
                        ->maxValue(168)
                        ->suffix('ساعة')
                        ->helperText('مثال: 2 = لا يمكن إلغاء الحجز المؤكد إذا تبقّى أقل من ساعتين على الموعد.'),
                ])
                ->columns(2)
                ->columnSpanFull(),
        ]);
    }

    public function content(Schema $schema): Schema
    {
        return $schema->components([
            Form::make([EmbeddedSchema::make('form')])
                ->id('form')
                ->livewireSubmitHandler('save')
                ->footer([
                    Actions::make([
                        Action::make('save')
                            ->label('حفظ الإعدادات')
                            ->submit('save'),
                    ]),
                ]),
        ]);
    }

    public function save(): void
    {
        $setting = BookingSetting::current();
        $setting->fill($this->form->getState());
        $setting->save();

        Notification::make()
            ->title('تم حفظ إعدادات إلغاء الحجوزات')
            ->success()
            ->send();
    }
}
