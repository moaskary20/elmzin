<?php

namespace Tests\Feature;

use App\Enums\LoyaltyTransactionType;
use App\Enums\UserRole;
use App\Models\LoyaltySetting;
use App\Models\LoyaltyTransaction;
use App\Models\User;
use App\Services\OfferService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

class LoyaltyScreenTest extends TestCase
{
    use RefreshDatabase;

    public function test_customer_sees_points_rules_progress_and_history(): void
    {
        LoyaltySetting::current()->update([
            'is_active' => true,
            'earn_amount' => 10,
            'earn_points' => 1,
            'redeem_points' => 100,
            'redeem_value' => 10,
            'min_redeem_points' => 100,
            'points_expire_days' => 365,
        ]);

        $user = User::query()->create([
            'name' => 'عميل',
            'email' => 'client@test.local',
            'phone' => '0111',
            'password' => 'secret12',
            'role' => UserRole::Customer,
            'is_active' => true,
        ]);
        $raw = Str::random(60);
        $user->forceFill(['api_token' => hash('sha256', $raw)])->save();

        $this->getJson('/api/account/loyalty')->assertStatus(401);

        LoyaltyTransaction::query()->create([
            'user_id' => $user->id,
            'type' => LoyaltyTransactionType::Earn,
            'points' => 80,
            'balance_after' => 0,
            'note' => 'اكتساب من حجز',
            'expires_at' => now()->addDays(10),
        ]);
        app(OfferService::class)->adjust($user->fresh(), 170, 'هدية');
        app(OfferService::class)->recalculate($user->fresh());

        $this->withToken($raw)->getJson('/api/account/loyalty')
            ->assertOk()
            ->assertJsonPath('data.points', 250)
            ->assertJsonPath('data.redeemable_points', 200)
            ->assertJsonPath('data.redeemable_value', 20)
            ->assertJsonPath('data.next_reward.target', 300)
            ->assertJsonPath('data.next_reward.remaining', 50)
            ->assertJsonPath('data.next_reward.value', 30)
            ->assertJsonPath('data.rules.earn_amount', 10)
            ->assertJsonPath('data.rules.expire_days', 365)
            ->assertJsonPath('data.totals.earned', 250)
            ->assertJsonPath('data.expiring.points', 80)
            ->assertJsonPath('data.expiring.date', now()->addDays(10)->toDateString())
            ->assertJsonCount(2, 'data.transactions')
            ->assertJsonPath('data.transactions.0.type', 'adjust')
            ->assertJsonPath('data.transactions.0.points', 170)
            ->assertJsonPath('data.transactions.1.expires_at', now()->addDays(10)->toDateString());
    }
}
