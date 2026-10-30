<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('specialists', 'name_en')) {
            Schema::table('specialists', function (Blueprint $table) {
                $table->string('name_en')->nullable()->after('name');
            });
        }

        foreach ([
            'حماده' => 'Hamada',
            'ali style' => 'Ali Style',
            'Ali Style' => 'Ali Style',
        ] as $ar => $en) {
            DB::table('salons')->where('name', $ar)->update(['name_en' => $en]);
            DB::table('salons')->where('name', $ar)->where(function ($query): void {
                $query->whereNull('about_en')->orWhere('about_en', '');
            })->update(['about_en' => 'Join request from the mobile app.']);
        }

        foreach ($this->serviceNames() as $ar => $en) {
            DB::table('catalog_services')->where('name', $ar)->update(['name_en' => $en]);
            DB::table('services')->where('name', $ar)->update(['name_en' => $en]);
        }

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
                if (! filled($service->name_en) && filled($catalog->name_en ?? null)) {
                    $payload['name_en'] = $catalog->name_en;
                }
                if (! filled($service->description_en) && filled($catalog->description_en ?? null)) {
                    $payload['description_en'] = $catalog->description_en;
                }
                if ($payload !== []) {
                    DB::table('services')->where('id', $service->id)->update($payload);
                }
            });

        $titleMap = [
            'حلاق' => 'Barber',
            'حلاق أول' => 'Senior barber',
            'خبير لحية' => 'Beard specialist',
            'أخصائي لحية' => 'Beard specialist',
            'أخصائية تجميل' => 'Beautician',
            'خبيرة تجميل' => 'Beautician',
            'مصففة أطفال' => 'Kids stylist',
            'مصففة' => 'Stylist',
            'مصففة شعر' => 'Hair stylist',
            'مصفف شعر' => 'Hair stylist',
            'أخصائية بشرة' => 'Skin specialist',
            'حلاق أطفال' => 'Kids barber',
        ];
        foreach ($titleMap as $ar => $en) {
            DB::table('specialists')->where('title', $ar)->update(['title_en' => $en]);
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('specialists', 'name_en')) {
            Schema::table('specialists', function (Blueprint $table) {
                $table->dropColumn('name_en');
            });
        }
    }

    /** @return array<string, string> */
    private function serviceNames(): array
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
};
