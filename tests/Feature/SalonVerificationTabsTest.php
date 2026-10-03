<?php

namespace Tests\Feature;

use App\Enums\UserRole;
use App\Enums\VerificationStatus;
use App\Filament\Resources\Salons\Pages\EditSalon;
use App\Filament\Resources\Salons\Pages\ListSalons;
use App\Models\Category;
use App\Models\Salon;
use App\Models\User;
use Filament\Actions\Testing\TestAction;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Livewire\Livewire;
use Tests\TestCase;

class SalonVerificationTabsTest extends TestCase
{
    use RefreshDatabase;

    private Category $category;

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
        $this->category = Category::query()->create(['name' => 'رجالي', 'slug' => 'men', 'is_active' => true]);
    }

    public function test_salons_split_into_verified_and_pending_tabs(): void
    {
        $verified = $this->salon('صالون موثق', VerificationStatus::Verified);
        $pending = $this->salon('صالون جديد', VerificationStatus::Pending);
        $other = $this->salon('صالون آخر', VerificationStatus::Pending);

        Livewire::test(ListSalons::class)
            ->assertSee('الصالونات الموثقة')
            ->assertSee('في انتظار التوثيق')
            ->assertCanSeeTableRecords([$verified])
            ->assertCanNotSeeTableRecords([$pending, $other])
            ->set('activeTab', 'pending')
            ->assertCanSeeTableRecords([$pending, $other])
            ->assertCanNotSeeTableRecords([$verified])
            ->callAction(TestAction::make('verify')->table($pending))
            ->callAction(TestAction::make('reject')->table($other))
            ->assertCanNotSeeTableRecords([$pending, $other]);

        $this->assertSame(VerificationStatus::Verified, $pending->fresh()->verification_status);
        $this->assertSame(VerificationStatus::Rejected, $other->fresh()->verification_status);

        Livewire::test(ListSalons::class)
            ->assertCanSeeTableRecords([$verified, $pending])
            ->assertSee('المرفوضة');
    }

    public function test_salon_login_details_show_and_the_password_can_be_reset(): void
    {
        $owner = User::query()->create([
            'name' => 'owner',
            'email' => 'owner@test.local',
            'phone' => '0123456789',
            'password' => 'oldpass1',
            'role' => UserRole::Salon,
            'is_active' => true,
        ]);
        $salon = $this->salon('صالون الحساب', VerificationStatus::Verified, $owner);
        $lonely = $this->salon('صالون بلا حساب', VerificationStatus::Verified);

        Livewire::test(ListSalons::class)
            ->assertSee('بيانات الدخول')
            ->assertSee('owner@test.local')
            ->assertSee('0123456789')
            ->assertSee('بدون حساب');

        Livewire::test(EditSalon::class, ['record' => $salon->getRouteKey()])
            ->assertSchemaStateSet(['owner.email' => 'owner@test.local', 'owner.phone' => '0123456789'])
            ->fillForm(['owner.password' => 'newpass9'])
            ->call('save')
            ->assertHasNoFormErrors();
        $this->assertTrue(Hash::check('newpass9', $owner->fresh()->password));

        Livewire::test(EditSalon::class, ['record' => $salon->getRouteKey()])
            ->call('save')
            ->assertHasNoFormErrors();
        $this->assertTrue(Hash::check('newpass9', $owner->fresh()->password));

        Livewire::test(EditSalon::class, ['record' => $lonely->getRouteKey()])
            ->fillForm(['owner.email' => 'owner@test.local', 'owner.password' => 'abcdef1'])
            ->call('save')
            ->assertHasFormErrors(['owner.email' => 'unique']);

        Livewire::test(EditSalon::class, ['record' => $lonely->getRouteKey()])
            ->fillForm(['owner.email' => 'lonely@test.local', 'owner.phone' => '0155', 'owner.password' => 'abcdef1'])
            ->call('save')
            ->assertHasNoFormErrors();
        $created = $lonely->fresh()->owner;
        $this->assertSame('lonely@test.local', $created->email);
        $this->assertSame(UserRole::Salon, $created->role);
        $this->assertTrue(Hash::check('abcdef1', $created->password));
    }

    private function salon(string $name, VerificationStatus $status, ?User $owner = null): Salon
    {
        return Salon::query()->create([
            'category_id' => $this->category->id,
            'user_id' => $owner?->id,
            'name' => $name,
            'phone' => '0101',
            'city' => 'القاهرة',
            'address' => 'شارع',
            'latitude' => 30,
            'longitude' => 31,
            'is_active' => true,
            'verification_status' => $status,
        ]);
    }
}
