<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('subscription_plans', function (Blueprint $table) {
            $table->string('name_en')->nullable()->after('name');
            $table->string('tagline_en')->nullable()->after('tagline');
            $table->string('badge_en')->nullable()->after('badge');
            $table->json('features_en')->nullable()->after('features');
            $table->text('terms_en')->nullable()->after('terms');
        });

        DB::table('subscription_plans')->orderBy('id')->get()->each(function ($plan): void {
            if (filled($plan->name_en)) {
                return;
            }

            DB::table('subscription_plans')->where('id', $plan->id)->update([
                'name_en' => 'Starter Plan',
                'tagline_en' => 'Free subscription for a full year',
                'badge_en' => 'Free for one year',
                'features_en' => json_encode([
                    'Appear to Al-Muzayyin customers in your area',
                    'Receive and manage bookings from the app',
                    'Add services, prices, and specialists without limits',
                    'Instant notifications for every booking and review',
                    'Customer reviews and a dedicated salon page',
                ], JSON_UNESCAPED_UNICODE),
                'terms_en' => implode("\n", [
                    'The subscription is completely free for one year from signup, and no payment details are required.',
                    'Salon details, photos, and prices must be accurate and kept up to date.',
                    'The salon must confirm or cancel bookings on time and respect customer appointments.',
                    'Al-Muzayyin may suspend accounts that violate the terms or receive repeated customer complaints.',
                    'When the free year ends, you can move to a paid plan without losing your data.',
                ]),
                'updated_at' => now(),
            ]);
        });

        foreach ($this->catalogNames() as $ar => $en) {
            DB::table('catalog_services')->where('name', $ar)->where(function ($query): void {
                $query->whereNull('name_en')->orWhere('name_en', '');
            })->update(['name_en' => $en]);

            DB::table('services')->where('name', $ar)->where(function ($query): void {
                $query->whereNull('name_en')->orWhere('name_en', '');
            })->update(['name_en' => $en]);
        }

        foreach ($this->catalogDescriptions() as $ar => $en) {
            DB::table('catalog_services')->where('name', $ar)->where(function ($query): void {
                $query->whereNull('description_en')->orWhere('description_en', '');
            })->update(['description_en' => $en]);

            DB::table('services')->where('name', $ar)->where(function ($query): void {
                $query->whereNull('description_en')->orWhere('description_en', '');
            })->update(['description_en' => $en]);
        }

        // Copy remaining English from catalog rows onto salon services.
        DB::table('services')
            ->whereNotNull('catalog_service_id')
            ->orderBy('id')
            ->get(['id', 'catalog_service_id', 'name_en', 'description_en'])
            ->each(function ($service): void {
                $catalog = DB::table('catalog_services')->where('id', $service->catalog_service_id)->first();
                if (! $catalog) {
                    return;
                }
                $payload = [];
                if (! filled($service->name_en) && filled($catalog->name_en)) {
                    $payload['name_en'] = $catalog->name_en;
                }
                if (! filled($service->description_en) && filled($catalog->description_en)) {
                    $payload['description_en'] = $catalog->description_en;
                }
                if ($payload !== []) {
                    DB::table('services')->where('id', $service->id)->update($payload);
                }
            });

        DB::table('salons')->where('id', 12)->where(function ($query): void {
            $query->whereNull('name_en')->orWhere('name_en', '');
        })->update([
            'name_en' => 'Hamada',
            'about_en' => 'Join request from the mobile app.',
        ]);
    }

    public function down(): void
    {
        Schema::table('subscription_plans', function (Blueprint $table) {
            $table->dropColumn(['name_en', 'tagline_en', 'badge_en', 'features_en', 'terms_en']);
        });
    }

    /** @return array<string, string> */
    private function catalogNames(): array
    {
        return [
            'قص شعر' => 'Haircut',
            'تهذيب لحية' => 'Beard trim',
            'حلاقة كاملة' => 'Full shave',
            'حلاقة ذقن بالموس' => 'Straight-razor shave',
            'سشوار وتصفيف' => 'Blow-dry & styling',
            'صبغة شعر' => 'Hair color',
            'صبغة لحية' => 'Beard color',
            'تنظيف بشرة' => 'Facial cleansing',
            'ماسك الفحم' => 'Charcoal mask',
            'حمام زيت' => 'Oil treatment',
            'بروتين وكيراتين' => 'Protein & keratin',
            'إزالة الشعر بالخيط' => 'Thread hair removal',
            'باكيج العريس' => 'Groom package',
            'قص وتصفيف' => 'Cut & style',
            'سشوار' => 'Blow-dry',
            'هايلايت' => 'Highlights',
            'حمام كريم' => 'Cream bath',
            'تسريحة مناسبات' => 'Occasion hairstyle',
            'مكياج سهرة' => 'Evening makeup',
            'مكياج عروس' => 'Bridal makeup',
            'عناية بشرة' => 'Skin care',
            'مانيكير' => 'Manicure',
            'باديكير' => 'Pedicure',
            'رسم حواجب وخيط' => 'Brow shaping & threading',
            'تركيب رموش' => 'Lash extensions',
            'حنة' => 'Henna',
            'باكيج العروس' => 'Bridal package',
            'قصة أطفال' => 'Kids haircut',
            'قصة أول مرة' => 'First haircut',
            'رسمات شعر' => 'Hair designs',
            'تسريحة بنات' => 'Girls hairstyle',
            'ضفائر' => 'Braids',
            'تسريحة حفلات' => 'Party hairstyle',
            'رسم على الوجه' => 'Face painting',
            'مانيكير أطفال' => 'Kids manicure',
            'تريتمنت للشعر' => 'Hair treatment',
            'تشقير للوجه' => 'Facial bleaching',
            'حمام مغربي' => 'Moroccan bath',
            'سويت لكامل الجسم' => 'Full-body sweet',
            'حمامات بخار للوجه والشعر' => 'Steam bath for face & hair',
            'ميكروبليندنج للحواجب' => 'Microblading brows',
            'تسريحة' => 'Hairstyling',
            'صبغة جذور' => 'Root color',
            'حلاقة كلاسيكية' => 'Classic shave',
            'عناية بالبشرة' => 'Skin care',
            'مكياج' => 'Makeup',
        ];
    }

    /** @return array<string, string> */
    private function catalogDescriptions(): array
    {
        return [
            'قص شعر' => 'Professional haircut tailored to your style.',
            'تهذيب لحية' => 'Clean beard trim and shaping.',
            'حلاقة كاملة' => 'Complete shave and finish.',
            'صبغة شعر' => 'Hair coloring with care for scalp and shine.',
            'مكياج سهرة' => 'Evening makeup for special nights out.',
            'مكياج عروس' => 'Bridal makeup for your wedding day.',
            'قصة أطفال' => 'Gentle kids haircut in a comfortable setting.',
            'مانيكير' => 'Classic manicure for neat, polished nails.',
            'باديكير' => 'Relaxing pedicure and nail care.',
            'بروتين وكيراتين' => 'Smoothing protein and keratin treatment.',
            'باكيج العروس' => 'Full bridal beauty package.',
            'باكيج العريس' => 'Full groom grooming package.',
        ];
    }
};
