<?php

namespace Tests\Feature;

use App\Enums\UserRole;
use App\Models\SellerProfile;
use App\Models\SellerSubscription;
use App\Models\ShopCategory;
use App\Models\ShopProduct;
use App\Models\SubscriptionPlan;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class SellerAccountTest extends TestCase
{
    use RefreshDatabase;

    public function test_seller_register_creates_profile_subscription_and_products_show_seller_name(): void
    {
        Storage::fake('public');

        $plan = SubscriptionPlan::query()->available()->firstOrFail();
        $category = ShopCategory::query()->create([
            'name' => 'عناية الشعر',
            'name_en' => 'Hair care',
            'slug' => 'hair-care',
            'is_active' => true,
            'sort_order' => 1,
        ]);

        $this->postJson('/api/auth/register', [
            'account_type' => 'seller',
            'name' => 'بائع المزين',
            'email' => 'seller@test.local',
            'phone' => '01011112222',
            'password' => 'secret12',
            'address' => 'شارع التحرير',
            'latitude' => 30.04,
            'longitude' => 31.24,
            'national_id' => '29501011234567',
            'plan_id' => $plan->id,
        ])->assertStatus(422)->assertJsonValidationErrors('accept_terms');

        $token = $this->postJson('/api/auth/register', [
            'account_type' => 'seller',
            'name' => 'بائع المزين',
            'email' => 'seller@test.local',
            'phone' => '01011112222',
            'password' => 'secret12',
            'address' => 'شارع التحرير',
            'latitude' => 30.04,
            'longitude' => 31.24,
            'national_id' => '29501011234567',
            'plan_id' => $plan->id,
            'accept_terms' => true,
        ])->assertCreated()->json('token');

        $user = User::query()->where('email', 'seller@test.local')->firstOrFail();
        $this->assertSame(UserRole::Seller, $user->role);

        $profile = SellerProfile::query()->where('user_id', $user->id)->firstOrFail();
        $this->assertSame('29501011234567', $profile->national_id);

        $this->assertTrue(
            SellerSubscription::query()
                ->where('user_id', $user->id)
                ->where('status', 'active')
                ->exists()
        );

        $this->withToken($token)->post('/api/account/seller/national-id', [
            'image' => UploadedFile::fake()->image('id.jpg'),
        ])->assertOk();

        $this->withToken($token)->post('/api/account/seller/commercial-register', [
            'image' => UploadedFile::fake()->image('cr.jpg'),
        ])->assertOk();

        $profile->refresh();
        $this->assertNotNull($profile->national_id_image);
        $this->assertNotNull($profile->commercial_register_image);
        Storage::disk('public')->assertExists($profile->national_id_image);
        Storage::disk('public')->assertExists($profile->commercial_register_image);

        $created = $this->withToken($token)->post('/api/seller/products', [
            'shop_category_id' => $category->id,
            'name' => 'زيت أرغان',
            'name_en' => 'Argan oil',
            'description' => 'زيت مغذي',
            'price' => 150,
            'stock' => 20,
            'is_active' => true,
            'image' => UploadedFile::fake()->image('product.jpg'),
        ])->assertCreated()->json('data');

        $this->assertSame('بائع المزين', $created['seller_name']);
        $this->assertNotNull($created['image_url']);

        $product = ShopProduct::query()->findOrFail($created['id']);
        $this->assertSame($user->id, $product->user_id);

        $this->getJson('/api/shop/catalog')
            ->assertOk()
            ->assertJsonFragment([
                'name' => 'زيت أرغان',
                'seller_name' => 'بائع المزين',
            ]);

        $this->withToken($token)->post('/api/seller/products/'.$product->id, [
            'price' => 175,
            'stock' => 15,
        ])->assertOk()->assertJsonPath('data.price', 175);

        $this->withToken($token)->deleteJson('/api/seller/products/'.$product->id)
            ->assertOk();

        $this->assertDatabaseMissing('shop_products', ['id' => $product->id]);
    }

    public function test_seller_register_requires_plan_and_national_id(): void
    {
        $this->postJson('/api/auth/register', [
            'account_type' => 'seller',
            'name' => 'بائع',
            'email' => 'seller2@test.local',
            'phone' => '01033334444',
            'password' => 'secret12',
            'address' => 'شارع',
            'latitude' => 30,
            'longitude' => 31,
            'accept_terms' => true,
        ])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['national_id', 'plan_id']);
    }
}
