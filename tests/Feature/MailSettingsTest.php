<?php

namespace Tests\Feature;

use App\Enums\UserRole;
use App\Filament\Pages\ManageMailSettings;
use App\Models\MailSetting;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use Livewire\Livewire;
use Tests\TestCase;

class MailSettingsTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->actingAs(User::query()->create([
            'name' => 'مدير',
            'email' => 'admin@test.local',
            'phone' => '0100000000',
            'password' => 'secret12',
            'role' => UserRole::Admin,
            'is_active' => true,
        ]));
    }

    public function test_admin_saves_brevo_settings_and_keeps_the_saved_key(): void
    {
        $this->get('/admin/mail-settings')->assertOk()->assertSee('إعدادات البريد الإلكتروني');

        Livewire::test(ManageMailSettings::class)
            ->fillForm([
                'is_active' => true,
                'transport' => 'api',
                'api_key' => 'xkeysib-secret-1234',
                'from_address' => 'no-reply@muzayen.test',
                'from_name' => 'المزين',
            ])
            ->call('save')
            ->assertHasNoFormErrors()
            ->assertSchemaStateSet(['api_key' => null]);

        $setting = MailSetting::current();
        $this->assertTrue($setting->isReady());
        $this->assertSame('xkeysib-secret-1234', $setting->api_key);
        $this->assertNotSame('xkeysib-secret-1234', $setting->getRawOriginal('api_key'));

        Livewire::test(ManageMailSettings::class)
            ->fillForm(['from_name' => 'المزين للحجوزات'])
            ->call('save')
            ->assertHasNoFormErrors();

        $setting->refresh();
        $this->assertSame('xkeysib-secret-1234', $setting->api_key);
        $this->assertSame('المزين للحجوزات', $setting->from_name);
    }

    public function test_active_settings_require_a_sender_and_key(): void
    {
        Livewire::test(ManageMailSettings::class)
            ->fillForm([
                'is_active' => true,
                'transport' => 'smtp',
                'smtp_login' => '',
                'from_address' => '',
            ])
            ->call('save')
            ->assertHasFormErrors(['smtp_login' => 'required', 'smtp_password' => 'required', 'from_address' => 'required']);

        $this->assertFalse(MailSetting::current()->is_active);
    }

    public function test_password_reset_mail_goes_through_the_brevo_api(): void
    {
        Http::fake([
            'api.brevo.com/v3/smtp/email' => Http::response(['messageId' => '<abc@brevo>'], 201),
            'api.brevo.com/v3/account' => Http::response(['email' => 'owner@brevo.test', 'companyName' => 'Muzayen', 'plan' => [['type' => 'free', 'credits' => 300]]]),
        ]);

        MailSetting::current()->update([
            'is_active' => true,
            'transport' => 'api',
            'api_key' => 'xkeysib-live',
            'from_address' => 'no-reply@muzayen.test',
            'from_name' => 'المزين',
        ]);
        MailSetting::apply();
        $this->assertSame('brevo', config('mail.default'));

        User::query()->create([
            'name' => 'عميل',
            'email' => 'client@test.local',
            'phone' => '0111',
            'password' => 'secret12',
            'role' => UserRole::Customer,
            'is_active' => true,
        ]);

        $this->postJson('/api/auth/forgot-password', ['email' => 'client@test.local'])->assertOk();

        Http::assertSent(function (Request $request): bool {
            return $request->url() === 'https://api.brevo.com/v3/smtp/email'
                && $request->hasHeader('api-key', 'xkeysib-live')
                && $request['sender']['email'] === 'no-reply@muzayen.test'
                && $request['to'][0]['email'] === 'client@test.local'
                && str_contains($request['subject'], 'استعادة')
                && str_contains($request['textContent'], 'رمز استعادة');
        });

        Livewire::test(ManageMailSettings::class)
            ->set('data.test_to', 'me@test.local')
            ->call('sendTest')
            ->assertNotified('تم إرسال الرسالة التجريبية');

        Http::assertSent(fn (Request $request): bool => str_contains($request->url(), '/smtp/email')
            && $request['to'][0]['email'] === 'me@test.local');

        Livewire::test(ManageMailSettings::class)
            ->call('check')
            ->assertNotified('الاتصال بـ Brevo ناجح');
    }
}
