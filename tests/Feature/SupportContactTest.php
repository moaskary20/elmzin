<?php

namespace Tests\Feature;

use App\Enums\UserRole;
use App\Models\SupportOption;
use App\Models\SupportTicket;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SupportContactTest extends TestCase
{
    use RefreshDatabase;

    public function test_support_form_lists_admin_options_and_accepts_ticket(): void
    {
        $this->getJson('/api/support/form')
            ->assertOk()
            ->assertJsonPath('topics.0.label', 'مشكلة في الحجز')
            ->assertJsonStructure(['topics', 'related', 'success_message']);

        $topicOther = SupportOption::query()->where('field', 'topic')->where('is_other', true)->firstOrFail();
        $related = SupportOption::query()->where('field', 'related')->where('is_other', false)->firstOrFail();

        $user = User::query()->create([
            'name' => 'عميل',
            'email' => 'client@test.local',
            'phone' => '01011112222',
            'password' => 'secret12',
            'role' => UserRole::Customer,
            'is_active' => true,
        ]);
        $user->forceFill(['api_token' => hash('sha256', 'plain-token')])->save();
        $token = 'plain-token';

        $this->postJson('/api/support/tickets', [
            'topic_option_id' => $topicOther->id,
            'related_option_id' => $related->id,
        ], ['Authorization' => 'Bearer '.$token])
            ->assertStatus(422);

        $this->postJson('/api/support/tickets', [
            'topic_option_id' => $topicOther->id,
            'topic_custom' => 'لا أستطيع تعديل ملفي',
            'related_option_id' => $related->id,
            'message' => 'تفاصيل إضافية',
        ], ['Authorization' => 'Bearer '.$token])
            ->assertCreated()
            ->assertJsonPath('message', 'تم استلام رسالتك. سيتواصل معك فريق الدعم خلال 48 ساعة.');

        $this->assertSame(1, SupportTicket::query()->count());
        $ticket = SupportTicket::query()->firstOrFail();
        $this->assertSame('لا أستطيع تعديل ملفي', $ticket->topic_custom);
        $this->assertSame($user->id, $ticket->user_id);

        $this->actingAs(User::query()->create([
            'name' => 'مدير',
            'email' => 'admin-support@test.local',
            'phone' => '0100000001',
            'password' => 'secret12',
            'role' => UserRole::Admin,
            'is_active' => true,
        ]));

        $this->get('/admin/support-options')->assertOk()->assertSee('خيارات الدعم');
        $this->get('/admin/support-tickets')->assertOk()->assertSee('رسائل الدعم');
    }
}
