<?php

namespace App\Services;

use App\Models\ShopCategory;
use App\Models\ShopProduct;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Str;
use PhpOffice\PhpSpreadsheet\Cell\Coordinate;
use PhpOffice\PhpSpreadsheet\IOFactory;
use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;
use RuntimeException;
use Symfony\Component\HttpFoundation\StreamedResponse;

class ShopProductExcelService
{
    public const HEADERS = [
        'category' => 'القسم',
        'name' => 'اسم المنتج',
        'name_en' => 'اسم المنتج EN',
        'description' => 'الوصف',
        'description_en' => 'الوصف EN',
        'price' => 'السعر',
        'compare_at_price' => 'السعر قبل الخصم',
        'stock' => 'المخزون',
        'sort_order' => 'الترتيب',
        'is_active' => 'ظاهر للبيع',
    ];

    public function downloadTemplate(): StreamedResponse
    {
        $spreadsheet = new Spreadsheet;
        $sheet = $spreadsheet->getActiveSheet();
        $sheet->setTitle('المنتجات');

        $headers = array_values(self::HEADERS);
        foreach ($headers as $index => $header) {
            $column = Coordinate::stringFromColumnIndex($index + 1);
            $sheet->setCellValue($column.'1', $header);
            $sheet->getColumnDimension($column)->setAutoSize(true);
        }

        $categories = ShopCategory::query()
            ->orderBy('sort_order')
            ->orderBy('id')
            ->pluck('name')
            ->filter()
            ->values();

        $exampleCategory = $categories->first() ?: 'العناية بالشعر';

        $examples = [
            [$exampleCategory, 'شامبو مغذي', 'Nourishing Shampoo', 'وصف عربي مختصر', 'Short English description', 150, 200, 25, 1, 'نعم'],
            [$exampleCategory, 'زيت شعر', 'Hair Oil', '', '', 90, '', 10, 2, 'نعم'],
        ];

        foreach ($examples as $rowIndex => $row) {
            foreach ($row as $colIndex => $value) {
                $column = Coordinate::stringFromColumnIndex($colIndex + 1);
                $sheet->setCellValue($column.($rowIndex + 2), $value);
            }
        }

        $guide = $spreadsheet->createSheet();
        $guide->setTitle('إرشادات');
        $guide->setCellValue('A1', 'ملاحظات مهمة');
        $guide->setCellValue('A2', '1) اكتب اسم القسم كما هو في لوحة التحكم.');
        $guide->setCellValue('A3', '2) اسم المنتج والسعر مطلوبان.');
        $guide->setCellValue('A4', '3) ظاهر للبيع: نعم / لا أو 1 / 0.');
        $guide->setCellValue('A5', '4) احذف صفوف الأمثلة قبل الرفع أو عدّلها.');
        $guide->setCellValue('A7', 'أقسام متاحة حالياً:');

        $row = 8;
        foreach ($categories as $category) {
            $guide->setCellValue('A'.$row, $category);
            $row++;
        }

        if ($categories->isEmpty()) {
            $guide->setCellValue('A8', 'لا توجد أقسام بعد — أنشئ قسماً أولاً من التسوق > الأقسام.');
        }

        $guide->getColumnDimension('A')->setWidth(70);
        $spreadsheet->setActiveSheetIndex(0);

        $filename = 'قالب-منتجات-المزين.xlsx';

        return response()->streamDownload(function () use ($spreadsheet): void {
            (new Xlsx($spreadsheet))->save('php://output');
        }, $filename, [
            'Content-Type' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ]);
    }

    /**
     * @return array{created: int, updated: int, skipped: int, errors: list<string>}
     */
    public function import(UploadedFile $file): array
    {
        $path = $file->getRealPath();
        if ($path === false) {
            throw new RuntimeException('تعذر قراءة ملف الإكسل.');
        }

        $spreadsheet = IOFactory::load($path);
        $rows = $spreadsheet->getActiveSheet()->toArray(null, true, true, false);

        if ($rows === []) {
            throw new RuntimeException('ملف الإكسل فارغ.');
        }

        $headerRow = array_shift($rows);
        $map = $this->mapHeaders(array_map(fn ($value) => trim((string) $value), $headerRow ?? []));

        if (! isset($map['category'], $map['name'], $map['price'])) {
            throw new RuntimeException('ملف القالب غير مكتمل. يجب وجود أعمدة: القسم، اسم المنتج، السعر.');
        }

        $categories = ShopCategory::query()
            ->get()
            ->keyBy(fn (ShopCategory $category): string => $this->normalizeKey($category->name));

        $created = 0;
        $updated = 0;
        $skipped = 0;
        $errors = [];

        foreach ($rows as $index => $row) {
            $line = $index + 2;
            if ($this->rowEmpty($row)) {
                $skipped++;

                continue;
            }

            $categoryName = trim((string) ($row[$map['category']] ?? ''));
            $name = trim((string) ($row[$map['name']] ?? ''));
            $priceRaw = $row[$map['price']] ?? null;

            if ($categoryName === '' || $name === '' || $priceRaw === null || $priceRaw === '') {
                $errors[] = "صف {$line}: القسم واسم المنتج والسعر مطلوبة.";

                continue;
            }

            $category = $categories->get($this->normalizeKey($categoryName));
            if (! $category) {
                $errors[] = "صف {$line}: القسم «{$categoryName}» غير موجود.";

                continue;
            }

            $price = $this->toFloat($priceRaw);
            if ($price === null || $price < 0) {
                $errors[] = "صف {$line}: السعر غير صالح.";

                continue;
            }

            $payload = [
                'shop_category_id' => $category->id,
                'name' => $name,
                'name_en' => $this->nullableString($row[$map['name_en'] ?? -1] ?? null),
                'description' => $this->nullableString($row[$map['description'] ?? -1] ?? null),
                'description_en' => $this->nullableString($row[$map['description_en'] ?? -1] ?? null),
                'price' => $price,
                'compare_at_price' => $this->toFloat($row[$map['compare_at_price'] ?? -1] ?? null),
                'stock' => max(0, (int) round((float) ($row[$map['stock'] ?? -1] ?? 0))),
                'sort_order' => (int) round((float) ($row[$map['sort_order'] ?? -1] ?? 0)),
                'is_active' => $this->toBool($row[$map['is_active'] ?? -1] ?? true),
            ];

            $existing = ShopProduct::query()
                ->where('shop_category_id', $category->id)
                ->where('name', $name)
                ->first();

            if ($existing) {
                $existing->update($payload);
                $updated++;
            } else {
                ShopProduct::query()->create($payload);
                $created++;
            }
        }

        return compact('created', 'updated', 'skipped', 'errors');
    }

    /**
     * @param  list<string>  $headers
     * @return array<string, int>
     */
    private function mapHeaders(array $headers): array
    {
        $aliases = [
            'category' => ['القسم', 'قسم', 'category', 'category_name', 'shop_category'],
            'name' => ['اسم المنتج', 'المنتج', 'name', 'product_name'],
            'name_en' => ['اسم المنتج en', 'اسم المنتج (en)', 'name_en', 'name en', 'english name'],
            'description' => ['الوصف', 'description'],
            'description_en' => ['الوصف en', 'الوصف (en)', 'description_en', 'description en'],
            'price' => ['السعر', 'price'],
            'compare_at_price' => ['السعر قبل الخصم', 'سعر قبل الخصم', 'compare_at_price', 'old_price'],
            'stock' => ['المخزون', 'الكمية', 'stock', 'qty', 'quantity'],
            'sort_order' => ['الترتيب', 'ترتيب', 'sort_order', 'order'],
            'is_active' => ['ظاهر للبيع', 'ظاهر', 'نشط', 'is_active', 'active'],
        ];

        $map = [];
        foreach ($headers as $index => $header) {
            $normalized = $this->normalizeKey($header);
            foreach ($aliases as $field => $names) {
                if (isset($map[$field])) {
                    continue;
                }
                foreach ($names as $alias) {
                    if ($normalized === $this->normalizeKey($alias)) {
                        $map[$field] = $index;
                        break 2;
                    }
                }
            }
        }

        return $map;
    }

    private function normalizeKey(string $value): string
    {
        $value = Str::of($value)
            ->lower()
            ->replace(['أ', 'إ', 'آ'], 'ا')
            ->replace('ة', 'ه')
            ->replaceMatches('/\s+/u', ' ')
            ->trim()
            ->toString();

        return $value;
    }

    /**
     * @param  array<int, mixed>  $row
     */
    private function rowEmpty(array $row): bool
    {
        foreach ($row as $value) {
            if (trim((string) $value) !== '') {
                return false;
            }
        }

        return true;
    }

    private function nullableString(mixed $value): ?string
    {
        $text = trim((string) ($value ?? ''));

        return $text === '' ? null : $text;
    }

    private function toFloat(mixed $value): ?float
    {
        if ($value === null || $value === '') {
            return null;
        }

        if (is_numeric($value)) {
            return (float) $value;
        }

        $cleaned = str_replace([',', 'ج.م', 'EGP', ' '], ['', '', '', ''], (string) $value);

        return is_numeric($cleaned) ? (float) $cleaned : null;
    }

    private function toBool(mixed $value): bool
    {
        if (is_bool($value)) {
            return $value;
        }

        $normalized = $this->normalizeKey((string) $value);

        return ! in_array($normalized, ['0', 'no', 'false', 'لا', 'غير ظاهر', 'مخفي', 'inactive'], true);
    }
}
