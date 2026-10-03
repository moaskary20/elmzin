<?php

namespace App\Models;

use App\Mail\Transport\BrevoApiTransport;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Schema;
use Throwable;

class MailSetting extends Model
{
    public const CACHE_KEY = 'mail_settings.current';

    protected $fillable = [
        'is_active',
        'transport',
        'api_key',
        'smtp_host',
        'smtp_port',
        'smtp_encryption',
        'smtp_login',
        'smtp_password',
        'from_address',
        'from_name',
        'reply_to',
    ];

    protected $hidden = [
        'api_key',
        'smtp_password',
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
            'smtp_port' => 'integer',
            'api_key' => 'encrypted',
            'smtp_password' => 'encrypted',
        ];
    }

    protected static function booted(): void
    {
        static::saved(fn () => Cache::forget(self::CACHE_KEY));
    }

    public static function current(): self
    {
        return static::query()->firstOrCreate([], [
            'is_active' => false,
            'transport' => 'api',
            'smtp_host' => 'smtp-relay.brevo.com',
            'smtp_port' => 587,
            'smtp_encryption' => 'tls',
            'from_name' => config('app.name'),
        ]);
    }

    public function isReady(): bool
    {
        if (! $this->is_active || ! filled($this->from_address)) {
            return false;
        }

        return $this->transport === 'smtp'
            ? filled($this->smtp_login) && filled($this->smtp_password)
            : filled($this->api_key);
    }

    /**
     * Points Laravel's default mailer at Brevo when the saved settings are complete.
     */
    public static function apply(): void
    {
        try {
            if (! Schema::hasTable('mail_settings')) {
                return;
            }

            $setting = Cache::rememberForever(self::CACHE_KEY, fn () => static::query()->first());
        } catch (Throwable) {
            return;
        }

        if (! $setting instanceof self || ! $setting->isReady()) {
            return;
        }

        $setting->configure();
    }

    public function configure(): void
    {
        config([
            'mail.mailers.brevo' => $this->transport === 'smtp'
                ? [
                    'transport' => 'smtp',
                    'scheme' => $this->smtp_encryption === 'ssl' ? 'smtps' : 'smtp',
                    'host' => $this->smtp_host ?: 'smtp-relay.brevo.com',
                    'port' => $this->smtp_port ?: 587,
                    'username' => $this->smtp_login,
                    'password' => $this->smtp_password,
                    'timeout' => 15,
                ]
                : [
                    'transport' => 'brevo-api',
                    'key' => $this->api_key,
                ],
            'mail.default' => 'brevo',
            'mail.from.address' => $this->from_address,
            'mail.from.name' => $this->from_name ?: config('app.name'),
        ]);

        if (filled($this->reply_to)) {
            config(['mail.reply_to' => ['address' => $this->reply_to, 'name' => $this->from_name]]);
        }

        Mail::purge('brevo');
    }

    public static function registerTransport(): void
    {
        Mail::extend('brevo-api', fn (array $config) => new BrevoApiTransport((string) ($config['key'] ?? '')));
    }
}
