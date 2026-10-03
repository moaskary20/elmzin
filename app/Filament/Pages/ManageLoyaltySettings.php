<?php

namespace App\Filament\Pages;

use App\Models\LoyaltySetting;
use App\Services\OfferService;
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

class ManageLoyaltySettings extends Page
{
    protected static ?string $navigationLabel = 'نقاط الولاء';

    protected static ?string $title = 'نقاط الولاء';

    protected static string|\UnitEnum|null $navigationGroup = 'العروض';

    protected static ?string $slug = 'loyalty-settings';

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedSparkles;

    protected static ?int $navigationSort = 2;

    /**
     * @var array<string, mixed>|null
     */
    public ?array $data = [];

    public function mount(): void
    {
        app(OfferService::class)->expireDue();
        $this->form->fill(LoyaltySetting::current()->attributesToArray());
    }

    public function getSubheading(): ?string
    {
        return 'يكتسب العميل نقاطاً عند اكتمال الحجز، ويستبدلها خصماً. الإلغاء يعيد النقاط ويحرر الكوبون.';
    }

    public function defaultForm(Schema $schema): Schema
    {
        return $schema->statePath('data');
    }

    public function form(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('تشغيل البرنامج')
                ->schema([
                    Toggle::make('is_active')
                        ->label('برنامج النقاط يعمل')
                        ->default(true),
                ])
                ->columnSpanFull(),
            Section::make('الاكتساب')
                ->description('تُحسب النقاط على المبلغ المدفوع بعد الكوبون وخصم النقاط، وعند اكتمال الحجز فقط.')
                ->schema([
                    TextInput::make('earn_amount')
                        ->label('كل مبلغ')
                        ->numeric()
                        ->required()
                        ->minValue(1)
                        ->suffix('ج.م'),
                    TextInput::make('earn_points')
                        ->label('يمنح نقاطاً')
                        ->numeric()
                        ->required()
                        ->minValue(1)
                        ->suffix('نقطة'),
                    TextInput::make('points_expire_days')
                        ->label('صلاحية النقاط بالأيام')
                        ->numeric()
                        ->minValue(1)
                        ->helperText('اتركه فارغاً إذا كانت النقاط لا تنتهي. تُعالج النقاط المنتهية عند فتح هذه الصفحة أو حفظ حجز.'),
                ])
                ->columns(3)
                ->columnSpanFull(),
            Section::make('الاستبدال')
                ->schema([
                    TextInput::make('redeem_points')
                        ->label('كل مجموعة نقاط')
                        ->numeric()
                        ->required()
                        ->minValue(1)
                        ->suffix('نقطة'),
                    TextInput::make('redeem_value')
                        ->label('تساوي خصماً')
                        ->numeric()
                        ->required()
                        ->minValue(0)
                        ->suffix('ج.م'),
                    TextInput::make('min_redeem_points')
                        ->label('الحد الأدنى للاستبدال')
                        ->numeric()
                        ->required()
                        ->minValue(1)
                        ->suffix('نقطة'),
                ])
                ->columns(3)
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
        $setting = LoyaltySetting::current();
        $setting->fill($this->form->getState());
        $setting->save();

        Notification::make()
            ->title('تم حفظ إعدادات نقاط الولاء')
            ->success()
            ->send();
    }
}
