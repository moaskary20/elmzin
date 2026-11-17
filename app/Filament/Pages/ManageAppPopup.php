<?php

namespace App\Filament\Pages;

use App\Models\AppPopup;
use BackedEnum;
use Filament\Actions\Action;
use Filament\Forms\Components\Textarea;
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

class ManageAppPopup extends Page
{
    protected static ?string $navigationLabel = 'رسالة التطبيق';

    protected static ?string $title = 'رسالة منبثقة عند فتح التطبيق';

    protected static string|\UnitEnum|null $navigationGroup = 'تطبيق الموبايل';

    protected static ?string $slug = 'app-popup';

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedChatBubbleBottomCenterText;

    protected static ?int $navigationSort = 3;

    /**
     * @var array<string, mixed>|null
     */
    public ?array $data = [];

    public function mount(): void
    {
        $this->form->fill(AppPopup::current()->attributesToArray());
    }

    public function getSubheading(): ?string
    {
        return 'عند التفعيل تظهر الرسالة للمستخدم بعد اختيار اللغة مباشرة عند فتح التطبيق.';
    }

    public function defaultForm(Schema $schema): Schema
    {
        return $schema->statePath('data');
    }

    public function form(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('الرسالة المنبثقة')
                ->description('تحكم في ظهور الرسالة ونصها بالعربي والإنجليزي.')
                ->schema([
                    Toggle::make('is_active')
                        ->label('إظهار الرسالة في التطبيق')
                        ->helperText('عند الإيقاف لن تظهر أي رسالة عند فتح التطبيق.')
                        ->default(false)
                        ->columnSpanFull(),
                    TextInput::make('title')
                        ->label('العنوان (عربي)')
                        ->required()
                        ->maxLength(120),
                    TextInput::make('title_en')
                        ->label('العنوان (إنجليزي)')
                        ->maxLength(120),
                    Textarea::make('body')
                        ->label('نص الرسالة (عربي)')
                        ->required()
                        ->rows(4)
                        ->columnSpanFull(),
                    Textarea::make('body_en')
                        ->label('نص الرسالة (إنجليزي)')
                        ->rows(4)
                        ->columnSpanFull(),
                    TextInput::make('button_label')
                        ->label('نص الزر (عربي)')
                        ->required()
                        ->maxLength(40)
                        ->default('حسناً'),
                    TextInput::make('button_label_en')
                        ->label('نص الزر (إنجليزي)')
                        ->maxLength(40)
                        ->default('Got it'),
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
                            ->label('حفظ الرسالة')
                            ->submit('save'),
                    ]),
                ]),
        ]);
    }

    public function save(): void
    {
        $popup = AppPopup::current();
        $popup->fill($this->form->getState());
        $popup->save();

        Notification::make()
            ->title('تم حفظ رسالة التطبيق')
            ->success()
            ->send();
    }
}
