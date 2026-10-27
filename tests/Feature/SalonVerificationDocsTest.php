<?php

namespace Tests\Feature;

use App\Models\CatalogService;
use App\Models\Category;
use App\Models\Salon;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class SalonVerificationDocsTest extends TestCase
{
    use RefreshDatabase;

    public function test_salon_signup_requires_national_id_and_stores_health_certificate(): void
    {
        Storage::fake('public');

        $men = Category::query()->create(['name' => 'رجالي', 'slug' => 'men', 'is_active' => true]);
        $cut = CatalogService::query()->create([
            'category_id' => $men->id,
            'name' => 'قص شعر',
            'price' => 0,
            'is_active' => true,
        ]);

        $payload = [
            'account_type' => 'salon',
            'name' => 'صالون التوثيق',
            'email' => 'docs@test.local',
            'phone' => '01088887777',
            'password' => 'secret12',
            'address' => 'شارع',
            'latitude' => 30,
            'longitude' => 31,
            'category_id' => $men->id,
            'services' => [['id' => $cut->id, 'price' => 80]],
        ];

        $this->postJson('/api/auth/register', $payload)
            ->assertStatus(422)
            ->assertJsonValidationErrors('national_id');

        $token = $this->postJson('/api/auth/register', $payload + [
            'national_id' => '29501011234567',
        ])->assertCreated()->json('token');

        $salon = Salon::query()->where('name', 'صالون التوثيق')->firstOrFail();
        $this->assertSame('29501011234567', $salon->national_id);

        $this->withToken($token)->post('/api/account/salon/health-certificate', [
            'image' => UploadedFile::fake()->image('health.jpg'),
        ])->assertOk();

        $salon->refresh();
        $this->assertNotNull($salon->health_certificate);
        Storage::disk('public')->assertExists($salon->health_certificate);
        $this->assertNotNull(User::query()->where('email', 'docs@test.local')->first());
    }
}
