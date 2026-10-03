<?php

namespace App\Providers;

use App\Models\MailSetting;
use Illuminate\Support\Facades\Lang;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        MailSetting::registerTransport();
        MailSetting::apply();

        // addLines marks the group as loaded, so the vendor file must be loaded first.
        app('translator')->load('filament-forms', 'components', 'ar');

        Lang::addLines([
            'components.select.actions.clear.label' => 'مسح الاختيار',
            'components.text_input.actions.show_password.label' => 'عرض كلمة المرور',
            'components.text_input.actions.hide_password.label' => 'إخفاء كلمة المرور',
        ], 'ar', 'filament-forms');
    }
}
