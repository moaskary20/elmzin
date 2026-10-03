<?php

namespace App\Filament\Pages;

use App\Mail\Transport\BrevoApiTransport;
use App\Models\MailSetting;
use BackedEnum;
use Filament\Actions\Action;
use Filament\Forms\Components\Radio;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Notifications\Notification;
use Filament\Pages\Page;
use Filament\Schemas\Components\Actions;
use Filament\Schemas\Components\EmbeddedSchema;
use Filament\Schemas\Components\Form;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Components\Utilities\Get;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Mail;
use Throwable;

class ManageMailSettings extends Page
{
    protected static ?string $navigationLabel = 'إعدادات البريد';

    protected static ?string $title = 'إعدادات البريد الإلكتروني';

    protected static string|\UnitEnum|null $navigationGroup = 'الإعدادات';

    protected static ?string $slug = 'mail-settings';

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedEnvelope;

    protected static ?int $navigationSort = 1;

    /**
     * @var array<string, mixed>|null
     */
    public ?array $data = [];

    public function mount(): void
    {
        $setting = MailSetting::current();

        $this->form->fill([
            ...$setting->attributesToArray(),
            'api_key' => null,
            'smtp_password' => null,
            'test_to' => auth()->user()?->email,
        ]);
    }

    public function getSubheading(): ?string
    {
        $setting = MailSetting::current();

        if ($setting->isReady()) {
            return 'الإرسال يتم الآن عبر Brevo ('.($setting->transport === 'smtp' ? 'SMTP' : 'API').') من '.$setting->from_address.'.';
        }

        return 'البريد غير مفعّل حالياً، والرسائل (مثل رمز استعادة كلمة المرور) تُكتب في سجل النظام فقط.';
    }

    public function defaultForm(Schema $schema): Schema
    {
        return $schema->statePath('data');
    }

    public function form(Schema $schema): Schema
    {
        $setting = MailSetting::current();

        return $schema->components([
            Section::make('Brevo')
                ->description('أنشئ المفاتيح من لوحة brevo.com ← SMTP & API. يجب أن يكون بريد المرسل موثقاً في Brevo (Senders & Domains).')
                ->schema([
                    Toggle::make('is_active')
                        ->label('تفعيل الإرسال عبر Brevo')
                        ->columnSpanFull(),
                    Radio::make('transport')
                        ->label('طريقة الإرسال')
                        ->options([
                            'api' => 'Brevo API (مُوصى به)',
                            'smtp' => 'SMTP Relay',
                        ])
                        ->descriptions([
                            'api' => 'يستخدم مفتاح API الذي يبدأ بـ xkeysib-',
                            'smtp' => 'يستخدم بيانات SMTP ومفتاح يبدأ بـ xsmtpsib-',
                        ])
                        ->default('api')
                        ->inline()
                        ->live()
                        ->required()
                        ->columnSpanFull(),
                    TextInput::make('api_key')
                        ->label('مفتاح API')
                        ->password()
                        ->revealable()
                        ->autocomplete('new-password')
                        ->placeholder($setting->api_key ? 'محفوظ •••• '.substr((string) $setting->api_key, -4) : 'xkeysib-...')
                        ->helperText('اتركه فارغاً للإبقاء على المفتاح المحفوظ.')
                        ->required(fn (Get $get): bool => $get('transport') === 'api' && (bool) $get('is_active') && ! $setting->api_key)
                        ->visible(fn (Get $get): bool => $get('transport') === 'api')
                        ->columnSpanFull(),
                    TextInput::make('smtp_host')
                        ->label('خادم SMTP')
                        ->default('smtp-relay.brevo.com')
                        ->required(fn (Get $get): bool => $get('transport') === 'smtp')
                        ->visible(fn (Get $get): bool => $get('transport') === 'smtp'),
                    TextInput::make('smtp_port')
                        ->label('المنفذ')
                        ->numeric()
                        ->default(587)
                        ->helperText('587 مع TLS أو 465 مع SSL')
                        ->required(fn (Get $get): bool => $get('transport') === 'smtp')
                        ->visible(fn (Get $get): bool => $get('transport') === 'smtp'),
                    Select::make('smtp_encryption')
                        ->label('التشفير')
                        ->options(['tls' => 'TLS', 'ssl' => 'SSL'])
                        ->default('tls')
                        ->selectablePlaceholder(false)
                        ->visible(fn (Get $get): bool => $get('transport') === 'smtp'),
                    TextInput::make('smtp_login')
                        ->label('اسم مستخدم SMTP (Login)')
                        ->placeholder('xxxx@smtp-brevo.com')
                        ->required(fn (Get $get): bool => $get('transport') === 'smtp' && (bool) $get('is_active'))
                        ->visible(fn (Get $get): bool => $get('transport') === 'smtp'),
                    TextInput::make('smtp_password')
                        ->label('مفتاح SMTP')
                        ->password()
                        ->revealable()
                        ->autocomplete('new-password')
                        ->placeholder($setting->smtp_password ? 'محفوظ •••• '.substr((string) $setting->smtp_password, -4) : 'xsmtpsib-...')
                        ->helperText('اتركه فارغاً للإبقاء على المفتاح المحفوظ.')
                        ->required(fn (Get $get): bool => $get('transport') === 'smtp' && (bool) $get('is_active') && ! $setting->smtp_password)
                        ->visible(fn (Get $get): bool => $get('transport') === 'smtp')
                        ->columnSpan(2),
                ])
                ->columns(3)
                ->columnSpanFull(),
            Section::make('المرسل')
                ->schema([
                    TextInput::make('from_address')
                        ->label('بريد المرسل')
                        ->email()
                        ->placeholder('no-reply@example.com')
                        ->required(fn (Get $get): bool => (bool) $get('is_active')),
                    TextInput::make('from_name')
                        ->label('اسم المرسل')
                        ->placeholder('المزين')
                        ->maxLength(100),
                    TextInput::make('reply_to')
                        ->label('الرد على (اختياري)')
                        ->email(),
                ])
                ->columns(3)
                ->columnSpanFull(),
            Section::make('رسالة تجريبية')
                ->description('احفظ الإعدادات أولاً ثم أرسل رسالة للتأكد من وصول البريد.')
                ->schema([
                    TextInput::make('test_to')
                        ->label('إرسال إلى')
                        ->email()
                        ->dehydrated(false),
                ])
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
                        Action::make('check')
                            ->label('فحص الاتصال')
                            ->icon(Heroicon::OutlinedSignal)
                            ->color('gray')
                            ->action(fn () => $this->check()),
                        Action::make('sendTest')
                            ->label('إرسال رسالة تجريبية')
                            ->icon(Heroicon::OutlinedPaperAirplane)
                            ->color('gray')
                            ->action(fn () => $this->sendTest()),
                    ]),
                ]),
        ]);
    }

    public function save(): void
    {
        $state = $this->form->getState();
        $setting = MailSetting::current();

        foreach (['api_key', 'smtp_password'] as $secret) {
            if (blank($state[$secret] ?? null)) {
                unset($state[$secret]);
            }
        }

        $setting->fill($state);
        $setting->save();

        $this->form->fill([
            ...$setting->attributesToArray(),
            'api_key' => null,
            'smtp_password' => null,
            'test_to' => $this->data['test_to'] ?? null,
        ]);

        Notification::make()
            ->title('تم حفظ إعدادات البريد')
            ->body($setting->isReady() ? 'الرسائل ستُرسل عبر Brevo.' : 'الإرسال عبر Brevo غير مفعّل أو البيانات ناقصة.')
            ->success()
            ->send();
    }

    public function check(): void
    {
        $setting = MailSetting::current();

        if ($setting->transport === 'smtp') {
            $this->checkSmtp($setting);

            return;
        }

        if (! $setting->api_key) {
            $this->failure('احفظ مفتاح API أولاً.');

            return;
        }

        try {
            $response = Http::withHeaders(['api-key' => $setting->api_key])
                ->acceptJson()
                ->timeout(15)
                ->get(BrevoApiTransport::ENDPOINT.'/account');
        } catch (Throwable $e) {
            $this->failure('تعذر الوصول إلى Brevo: '.$e->getMessage());

            return;
        }

        if ($response->failed()) {
            $this->failure('رفض Brevo المفتاح: '.($response->json('message') ?: $response->status()));

            return;
        }

        $credits = collect($response->json('plan', []))
            ->map(fn (array $plan): string => ($plan['type'] ?? '').': '.($plan['credits'] ?? '—'))
            ->implode(' · ');

        Notification::make()
            ->title('الاتصال بـ Brevo ناجح')
            ->body(trim(($response->json('companyName') ?: '').' — '.($response->json('email') ?: '').($credits ? "\nالرصيد: {$credits}" : '')))
            ->success()
            ->send();
    }

    private function checkSmtp(MailSetting $setting): void
    {
        if (! $setting->smtp_login || ! $setting->smtp_password) {
            $this->failure('احفظ بيانات SMTP أولاً.');

            return;
        }

        try {
            $setting->configure();
            $transport = Mail::mailer('brevo')->getSymfonyTransport();
            if (method_exists($transport, 'start')) {
                $transport->start();
                $transport->stop();
            }
        } catch (Throwable $e) {
            $this->failure('فشل الاتصال بخادم SMTP: '.$e->getMessage());

            return;
        } finally {
            MailSetting::apply();
        }

        Notification::make()
            ->title('تم الاتصال بخادم SMTP بنجاح')
            ->success()
            ->send();
    }

    public function sendTest(): void
    {
        $to = $this->data['test_to'] ?? null;

        if (! filter_var($to, FILTER_VALIDATE_EMAIL)) {
            $this->failure('أدخل بريداً صحيحاً لإرسال الرسالة التجريبية.');

            return;
        }

        $setting = MailSetting::current();

        if (! $setting->isReady()) {
            $this->failure('فعّل Brevo واحفظ بيانات كاملة أولاً.');

            return;
        }

        try {
            $setting->configure();
            Mail::mailer('brevo')->raw(
                "هذه رسالة تجريبية من لوحة تحكم المزين.\nإذا وصلتك فإعدادات Brevo تعمل بشكل صحيح.\n\n".now()->format('Y-m-d H:i'),
                fn ($message) => $message->to($to)->subject('رسالة تجريبية - المزين'),
            );
        } catch (Throwable $e) {
            $this->failure('فشل الإرسال: '.$e->getMessage());

            return;
        }

        Notification::make()
            ->title('تم إرسال الرسالة التجريبية')
            ->body('إلى '.$to)
            ->success()
            ->send();
    }

    private function failure(string $message): void
    {
        Notification::make()
            ->title($message)
            ->danger()
            ->persistent()
            ->send();
    }
}
