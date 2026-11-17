<?php

namespace Tests\Feature;

use App\Models\AppPopup;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AppPopupApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_inactive_popup_returns_null_data(): void
    {
        AppPopup::current()->update(['is_active' => false]);

        $this->getJson('/api/popup')
            ->assertOk()
            ->assertJsonPath('data', null);
    }

    public function test_active_popup_returns_bilingual_payload(): void
    {
        AppPopup::current()->update([
            'is_active' => true,
            'title' => 'عرض خاص',
            'title_en' => 'Special offer',
            'body' => 'احجز اليوم واحصل على خصم.',
            'body_en' => 'Book today and get a discount.',
            'button_label' => 'موافق',
            'button_label_en' => 'OK',
        ]);

        $this->getJson('/api/popup')
            ->assertOk()
            ->assertJsonPath('data.title', 'عرض خاص')
            ->assertJsonPath('data.title_en', 'Special offer')
            ->assertJsonPath('data.body', 'احجز اليوم واحصل على خصم.')
            ->assertJsonPath('data.button_label', 'موافق');
    }
}
