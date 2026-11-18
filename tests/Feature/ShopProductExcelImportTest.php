<?php

namespace Tests\Feature;

use App\Enums\UserRole;
use App\Models\ShopCategory;
use App\Models\ShopProduct;
use App\Models\User;
use App\Services\ShopProductExcelService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use PhpOffice\PhpSpreadsheet\Cell\Coordinate;
use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;
use Tests\TestCase;

class ShopProductExcelImportTest extends TestCase
{
    use RefreshDatabase;

    public function test_excel_template_and_import_create_products(): void
    {
        $this->actingAs(User::query()->create([
            'name' => 'مدير',
            'email' => 'admin-shop@test.local',
            'phone' => '0100000099',
            'password' => 'secret12',
            'role' => UserRole::Admin,
            'is_active' => true,
        ]));

        $category = ShopCategory::query()->create([
            'name' => 'العناية بالشعر',
            'slug' => 'hair-care',
            'is_active' => true,
            'sort_order' => 1,
        ]);

        $excel = app(ShopProductExcelService::class);
        $response = $excel->downloadTemplate();
        $this->assertSame(200, $response->getStatusCode());

        $spreadsheet = new Spreadsheet;
        $sheet = $spreadsheet->getActiveSheet();
        $headers = array_values(ShopProductExcelService::HEADERS);
        foreach ($headers as $index => $header) {
            $sheet->setCellValue(Coordinate::stringFromColumnIndex($index + 1).'1', $header);
        }
        foreach ([
            'العناية بالشعر',
            'شامبو تجريبي',
            'Test Shampoo',
            'وصف',
            'Desc',
            120,
            150,
            8,
            3,
            'نعم',
        ] as $index => $value) {
            $sheet->setCellValue(Coordinate::stringFromColumnIndex($index + 1).'2', $value);
        }

        $temp = tempnam(sys_get_temp_dir(), 'products').'.xlsx';
        (new Xlsx($spreadsheet))->save($temp);

        $result = $excel->import(new UploadedFile($temp, 'products.xlsx', null, null, true));
        @unlink($temp);

        $this->assertSame(1, $result['created']);
        $this->assertSame([], $result['errors']);

        $product = ShopProduct::query()->where('name', 'شامبو تجريبي')->firstOrFail();
        $this->assertSame($category->id, $product->shop_category_id);
        $this->assertSame(120.0, (float) $product->price);
        $this->assertSame(8, $product->stock);
        $this->assertTrue($product->is_active);

        $this->get('/admin/shop-products')->assertOk()->assertSee('تحميل قالب Excel')->assertSee('رفع منتجات Excel');
    }
}
