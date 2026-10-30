<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('categories', function (Blueprint $table) {
            $table->string('name_en')->nullable()->after('name');
            $table->text('description_en')->nullable()->after('description');
        });

        Schema::table('salons', function (Blueprint $table) {
            $table->string('name_en')->nullable()->after('name');
            $table->text('about_en')->nullable()->after('about');
        });

        Schema::table('services', function (Blueprint $table) {
            $table->string('name_en')->nullable()->after('name');
            $table->text('description_en')->nullable()->after('description');
        });

        Schema::table('catalog_services', function (Blueprint $table) {
            $table->string('name_en')->nullable()->after('name');
            $table->text('description_en')->nullable()->after('description');
        });

        Schema::table('specialists', function (Blueprint $table) {
            $table->string('title_en')->nullable()->after('title');
            $table->text('bio_en')->nullable()->after('bio');
        });

        Schema::table('shop_categories', function (Blueprint $table) {
            $table->string('name_en')->nullable()->after('name');
            $table->text('description_en')->nullable()->after('description');
        });

        Schema::table('shop_products', function (Blueprint $table) {
            $table->string('name_en')->nullable()->after('name');
            $table->text('description_en')->nullable()->after('description');
        });

        $this->seedEnglishDemo();
    }

    public function down(): void
    {
        Schema::table('categories', function (Blueprint $table) {
            $table->dropColumn(['name_en', 'description_en']);
        });
        Schema::table('salons', function (Blueprint $table) {
            $table->dropColumn(['name_en', 'about_en']);
        });
        Schema::table('services', function (Blueprint $table) {
            $table->dropColumn(['name_en', 'description_en']);
        });
        Schema::table('catalog_services', function (Blueprint $table) {
            $table->dropColumn(['name_en', 'description_en']);
        });
        Schema::table('specialists', function (Blueprint $table) {
            $table->dropColumn(['title_en', 'bio_en']);
        });
        Schema::table('shop_categories', function (Blueprint $table) {
            $table->dropColumn(['name_en', 'description_en']);
        });
        Schema::table('shop_products', function (Blueprint $table) {
            $table->dropColumn(['name_en', 'description_en']);
        });
    }

    private function seedEnglishDemo(): void
    {
        $categories = [
            'men' => ['Men', 'Men’s grooming and classic cuts'],
            'women' => ['Women', 'Beauty and styling for women'],
            'kids' => ['Kids', 'Family-friendly kids cuts'],
        ];
        foreach ($categories as $slug => [$nameEn, $descriptionEn]) {
            DB::table('categories')->where('slug', $slug)->update([
                'name_en' => $nameEn,
                'description_en' => $descriptionEn,
            ]);
        }

        $salons = [
            1 => ['Al-Layth Salon', 'Classic cuts and beard care in a calm setting.'],
            2 => ['Beauty Touch', 'Women’s styling and beauty treatments.'],
            3 => ['Baraem', 'Kids haircuts in a comfortable family space.'],
            4 => ['Barber House', 'Neighborhood barbershop for everyday grooming.'],
            5 => ['Beauty House', 'Full women’s beauty salon.'],
            6 => ['Noor Atelier', 'Modern women’s styling studio.'],
            7 => ['Little Salon', 'Kids cuts inside the salon.'],
        ];
        foreach ($salons as $id => [$nameEn, $aboutEn]) {
            DB::table('salons')->where('id', $id)->update([
                'name_en' => $nameEn,
                'about_en' => $aboutEn,
            ]);
        }

        $serviceNames = [
            'قص شعر' => 'Haircut',
            'تهذيب لحية' => 'Beard trim',
            'صبغة شعر' => 'Hair color',
            'مكياج' => 'Makeup',
            'مانيكير' => 'Manicure',
            'قصة أطفال' => 'Kids haircut',
            'حلاقة كلاسيكية' => 'Classic shave',
            'عناية بالبشرة' => 'Skin care',
            'تسريحة' => 'Hairstyling',
            'صبغة جذور' => 'Root color',
        ];
        foreach ($serviceNames as $ar => $en) {
            DB::table('services')->where('name', $ar)->update(['name_en' => $en]);
            DB::table('catalog_services')->where('name', $ar)->update(['name_en' => $en]);
        }

        DB::table('specialists')->whereNotNull('title')->orderBy('id')->get(['id', 'title'])->each(function ($row): void {
            $map = [
                'حلاق' => 'Barber',
                'أخصائية تجميل' => 'Beautician',
                'مصففة أطفال' => 'Kids stylist',
                'مصففة' => 'Stylist',
            ];
            $titleEn = $map[$row->title] ?? null;
            if ($titleEn) {
                DB::table('specialists')->where('id', $row->id)->update(['title_en' => $titleEn]);
            }
        });

        $shopCategories = [
            'hair-care' => 'Hair care',
            'skin-care' => 'Skin care',
            'beard-tools' => 'Beard tools',
            'kids-fun' => 'Kids products',
        ];
        foreach ($shopCategories as $slug => $nameEn) {
            DB::table('shop_categories')->where('slug', $slug)->update(['name_en' => $nameEn]);
        }

        $products = [
            'زيت أرغان للشعر' => ['Argan hair oil', 'Nourishing oil for dry and damaged hair.'],
            'شامبو بروتين' => ['Protein shampoo', 'Strengthens hair and helps reduce shedding.'],
            'كريم تصفيف' => ['Styling cream', 'Light hold with a natural shine.'],
            'غسول وجه لطيف' => ['Gentle face wash', 'Cleanses without drying the skin.'],
            'ماسك فحم' => ['Charcoal mask', 'Clears pores and reduces blackheads.'],
            'كريم مرطب نهاري' => ['Day moisturizer', 'Daily hydration for all skin types.'],
            'زيت لحية خشبي' => ['Woody beard oil', 'Softens the beard with a light scent.'],
            'مشط لحية خشبي' => ['Wooden beard comb', 'Comb designed for beard grooming.'],
            'شامبو أطفال' => ['Kids shampoo', 'Gentle tear-free formula.'],
            'طلاء أظافر آمن' => ['Safe nail polish', 'Fun colors that remove easily.'],
        ];
        foreach ($products as $ar => [$nameEn, $descriptionEn]) {
            DB::table('shop_products')->where('name', $ar)->update([
                'name_en' => $nameEn,
                'description_en' => $descriptionEn,
            ]);
        }
    }
};
