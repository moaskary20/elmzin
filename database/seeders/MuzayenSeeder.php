<?php

namespace Database\Seeders;

use App\Enums\BookingStatus;
use App\Enums\UserRole;
use App\Enums\VerificationStatus;
use App\Enums\Weekday;
use App\Models\Booking;
use App\Models\Category;
use App\Models\Review;
use App\Models\Salon;
use App\Models\Service;
use App\Models\Specialist;
use App\Models\User;
use App\Models\WorkingHour;
use Illuminate\Database\Seeder;

class MuzayenSeeder extends Seeder
{
    public function run(): void
    {
        User::query()->updateOrCreate(
            ['email' => 'admin@muzayen.test'],
            [
                'name' => 'مدير المزين',
                'password' => 'muzayen123',
                'role' => UserRole::Admin,
                'is_active' => true,
            ],
        );

        $men = Category::query()->create([
            'name' => 'رجالي',
            'slug' => 'men',
            'description' => 'صالونات الحلاقة والعناية الرجالية.',
            'sort_order' => 1,
        ]);

        $women = Category::query()->create([
            'name' => 'حريمي',
            'slug' => 'women',
            'description' => 'صالونات التجميل والعناية النسائية.',
            'sort_order' => 2,
        ]);

        $kids = Category::query()->create([
            'name' => 'أطفال',
            'slug' => 'kids',
            'description' => 'صالونات الأطفال وقصات الشعر اللطيفة.',
            'sort_order' => 3,
        ]);

        $layth = $this->salon($men, [
            'name' => 'صالون الليث',
            'phone' => '01000000001',
            'city' => 'القاهرة',
            'district' => 'مدينة نصر',
            'address' => 'شارع عباس العقاد، أعلى كافيه النخبة',
            'about' => 'حلاقة كلاسيكية وعناية باللحية في أجواء هادئة.',
            'verification_status' => VerificationStatus::Verified,
        ], '10:00', '23:00');

        $lamsa = $this->salon($women, [
            'name' => 'لمسة جمال',
            'phone' => '01000000002',
            'city' => 'الجيزة',
            'district' => 'المهندسين',
            'address' => 'شارع شهاب، برج الأندلس، الدور الثالث',
            'about' => 'تجميل، صبغة، وعناية بالبشرة مع أخصائيات معتمدات.',
            'verification_status' => VerificationStatus::Verified,
        ], '12:00', '22:00');

        $baraem = $this->salon($kids, [
            'name' => 'براعم',
            'phone' => '01000000003',
            'city' => 'القاهرة',
            'district' => 'التجمع الخامس',
            'address' => 'التسعين الشمالي، مول الحديقة',
            'about' => 'قصات أطفال في مكان مريح ومناسب للعائلة.',
            'verification_status' => VerificationStatus::Pending,
        ], '11:00', '20:00');

        $cut = $this->service($layth, 'قص شعر', 120, 30);
        $beard = $this->service($layth, 'تهذيب لحية', 80, 20);
        $this->service($layth, 'حلاقة كاملة', 180, 45);

        $color = $this->service($lamsa, 'صبغة شعر', 450, 90);
        $this->service($lamsa, 'تسريحة مناسبات', 350, 60);
        $facial = $this->service($lamsa, 'عناية بشرة', 300, 50);

        $kidCut = $this->service($baraem, 'قصة أطفال', 90, 25);
        $this->service($baraem, 'رسمات شعر', 40, 15);

        $karim = $this->specialist($layth, 'كريم محمود', 'حلاق', [$cut->id, $beard->id]);
        $this->specialist($layth, 'يوسف عادل', 'أخصائي لحية', [$beard->id]);

        $nour = $this->specialist($lamsa, 'نورهان سيد', 'أخصائية تجميل', [$color->id, $facial->id]);
        $this->specialist($lamsa, 'مريم حسن', 'مصففة شعر', [$color->id]);

        $lina = $this->specialist($baraem, 'لينا عمر', 'مصففة أطفال', [$kidCut->id]);

        $booking = Booking::query()->create([
            'salon_id' => $layth->id,
            'specialist_id' => $karim->id,
            'service_id' => $cut->id,
            'customer_name' => 'أحمد سامي',
            'customer_phone' => '01111111111',
            'booked_on' => now()->addDay()->toDateString(),
            'booked_time' => '18:00',
            'status' => BookingStatus::Confirmed,
        ]);

        Review::query()->create([
            'salon_id' => $layth->id,
            'specialist_id' => $karim->id,
            'booking_id' => $booking->id,
            'customer_name' => 'أحمد سامي',
            'rating' => 5,
            'comment' => 'شغل نظيف وموعد دقيق.',
            'is_visible' => true,
        ]);

        Review::query()->create([
            'salon_id' => $lamsa->id,
            'specialist_id' => $nour->id,
            'customer_name' => 'سارة علي',
            'rating' => 4,
            'comment' => 'المكان راقٍ والخدمة مريحة.',
            'is_visible' => true,
        ]);

        $this->call(OffersSeeder::class);
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    private function salon(Category $category, array $attributes, string $opens, string $closes): Salon
    {
        $salon = $category->salons()->create($attributes);

        foreach (Weekday::cases() as $day) {
            $closed = $day === Weekday::Friday;

            WorkingHour::query()->create([
                'salon_id' => $salon->id,
                'day_of_week' => $day,
                'opens_at' => $closed ? null : $opens,
                'closes_at' => $closed ? null : $closes,
                'is_closed' => $closed,
            ]);
        }

        return $salon;
    }

    private function service(Salon $salon, string $name, float $price, int $minutes): Service
    {
        return $salon->services()->create([
            'name' => $name,
            'price' => $price,
            'duration_minutes' => $minutes,
            'is_active' => true,
        ]);
    }

    /**
     * @param  array<int, int>  $serviceIds
     */
    private function specialist(Salon $salon, string $name, string $title, array $serviceIds): Specialist
    {
        $specialist = $salon->specialists()->create([
            'name' => $name,
            'title' => $title,
            'is_active' => true,
        ]);

        $specialist->services()->sync($serviceIds);

        foreach ([Weekday::Saturday, Weekday::Sunday, Weekday::Monday, Weekday::Tuesday, Weekday::Wednesday, Weekday::Thursday] as $day) {
            foreach ([['16:00', '16:45'], ['17:00', '17:45'], ['18:00', '18:45'], ['19:00', '19:45']] as [$start, $end]) {
                $specialist->timeSlots()->create([
                    'day_of_week' => $day,
                    'starts_at' => $start,
                    'ends_at' => $end,
                    'is_active' => true,
                ]);
            }
        }

        return $specialist;
    }
}
