<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('avatar')->nullable()->after('longitude');
            $table->boolean('notifications_enabled')->default(true)->after('avatar');
            $table->boolean('dark_mode')->default(true)->after('notifications_enabled');
            $table->string('locale', 5)->default('ar')->after('dark_mode');
        });

        Schema::create('app_pages', function (Blueprint $table) {
            $table->id();
            $table->string('slug')->unique();
            $table->string('title');
            $table->string('title_en')->nullable();
            $table->text('intro')->nullable();
            $table->text('intro_en')->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();
        });

        Schema::create('app_page_blocks', function (Blueprint $table) {
            $table->id();
            $table->foreignId('app_page_id')->constrained()->cascadeOnDelete();
            $table->string('title');
            $table->string('title_en')->nullable();
            $table->text('body');
            $table->text('body_en')->nullable();
            $table->unsignedInteger('sort_order')->default(0);
            $table->timestamps();
        });

        $now = now();

        foreach ($this->pages() as $page) {
            $pageId = DB::table('app_pages')->insertGetId([
                'slug' => $page['slug'],
                'title' => $page['title'],
                'title_en' => $page['title_en'],
                'intro' => $page['intro'],
                'intro_en' => $page['intro_en'],
                'is_active' => true,
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            foreach ($page['blocks'] as $index => $block) {
                DB::table('app_page_blocks')->insert([
                    'app_page_id' => $pageId,
                    'title' => $block[0],
                    'body' => $block[1],
                    'title_en' => $block[2],
                    'body_en' => $block[3],
                    'sort_order' => $index,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('app_page_blocks');
        Schema::dropIfExists('app_pages');

        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['avatar', 'notifications_enabled', 'dark_mode', 'locale']);
        });
    }

    private function pages(): array
    {
        return [
            [
                'slug' => 'help',
                'title' => 'مركز المساعدة',
                'title_en' => 'Help center',
                'intro' => null,
                'intro_en' => null,
                'blocks' => [
                    ['احجز موعدًا', 'افتح صفحة الصالون، اختر الخدمة والأخصائي واليوم والوقت، ثم أدخل اسمك ورقم هاتفك.', 'Book a visit', 'Open a salon, choose a service, a specialist, a day, and a time, then enter your name and phone.'],
                    ['المفضلة', 'اضغط القلب على الصالون لحفظه. المفضلة تفتح من علامة القلب في رأس الصفحة الرئيسية.', 'Favorites', 'Tap the heart on a salon to save it. Open saved salons from the heart in the home header.'],
                    ['الخدمة المنزلية', 'من فلتر نوع الخدمة يمكنك إظهار الصالونات التي تقدّم زيارة منزلية.', 'Home service', 'Use the service-type filter to show salons that visit you at home.'],
                ],
            ],
            [
                'slug' => 'faq',
                'title' => 'الأسئلة الشائعة',
                'title_en' => 'FAQ',
                'intro' => null,
                'intro_en' => null,
                'blocks' => [
                    ['كيف أحجز؟', 'اختر الصالون ثم الخدمة واليوم والوقت، وأكّد الاسم ورقم الهاتف.', 'How do I book?', 'Choose the salon, the service, the day, and the time, then confirm your name and phone.'],
                    ['هل يصل الأخصائي إلى المنزل؟', 'الصالونات التي عليها علامة «منزلي» تقدّم زيارة. صفِّ القائمة بنوع الخدمة.', 'Can the stylist come to me?', 'Salons marked Home offer a visit. Filter the list by Home service.'],
                    ['أين تُحفظ المفضلة؟', 'على هذا الجهاز، وتبقى حتى تزيل علامة القلب.', 'Where are my favorites kept?', 'On this device. They stay until you remove the heart.'],
                    ['كيف أغيّر اللغة؟', 'من الإعدادات اختر اللغة، ثم العربية أو الإنجليزية.', 'How do I change the language?', 'Open Settings, then Language, and choose Arabic or English.'],
                ],
            ],
            [
                'slug' => 'privacy',
                'title' => 'سياسة الخصوصية',
                'title_en' => 'Privacy policy',
                'intro' => 'المزين يربط ملفك وتفضيلاتك بحسابك.',
                'intro_en' => 'Al-Muzayyin keeps your profile and preferences with your account.',
                'blocks' => [
                    ['ما يُحفظ مع الحساب', 'الاسم والهاتف والصورة والإشعارات والمظهر واللغة تُحفظ مع حسابك وتظهر في لوحة الإدارة.', 'What is saved with the account', 'Your name, phone, photo, notifications, appearance, and language are saved with your account and shown in the admin panel.'],
                    ['ماذا يُرسل مع الحجز', 'عند الحجز يُرسل اسمك ورقم هاتفك إلى الصالون لتأكيد الموعد.', 'What a booking sends', 'A booking sends your name and phone to the salon so they can confirm the visit.'],
                    ['العنوان', 'عنوان الحساب يُحدد من الخريطة عند إنشاء الحساب.', 'Address', 'The account address is chosen on the map when the account is created.'],
                ],
            ],
        ];
    }
};
