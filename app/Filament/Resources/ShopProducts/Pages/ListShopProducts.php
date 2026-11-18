<?php

namespace App\Filament\Resources\ShopProducts\Pages;

use App\Filament\Resources\ShopProductResource;
use App\Services\ShopProductExcelService;
use Filament\Actions\Action;
use Filament\Actions\CreateAction;
use Filament\Forms\Components\FileUpload;
use Filament\Notifications\Notification;
use Filament\Resources\Pages\ListRecords;
use Filament\Support\Icons\Heroicon;
use Illuminate\Support\Facades\Storage;
use Throwable;

class ListShopProducts extends ListRecords
{
    protected static string $resource = ShopProductResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Action::make('downloadTemplate')
                ->label('تحميل قالب Excel')
                ->icon(Heroicon::OutlinedArrowDownTray)
                ->color('gray')
                ->action(fn (ShopProductExcelService $excel) => $excel->downloadTemplate()),
            Action::make('importExcel')
                ->label('رفع منتجات Excel')
                ->icon(Heroicon::OutlinedArrowUpTray)
                ->color('warning')
                ->schema([
                    FileUpload::make('file')
                        ->label('ملف Excel')
                        ->acceptedFileTypes([
                            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                            'application/vnd.ms-excel',
                            'text/csv',
                            'text/plain',
                            'application/csv',
                        ])
                        ->disk('local')
                        ->directory('imports/shop-products')
                        ->required()
                        ->helperText('حمّل القالب أولاً، املأ المنتجات، ثم ارفع الملف هنا (.xlsx).'),
                ])
                ->modalHeading('استيراد منتجات من Excel')
                ->modalSubmitActionLabel('استيراد')
                ->action(function (array $data, ShopProductExcelService $excel): void {
                    $path = $data['file'] ?? null;
                    if (is_array($path)) {
                        $path = array_values($path)[0] ?? null;
                    }
                    if (! is_string($path) || $path === '' || ! Storage::disk('local')->exists($path)) {
                        Notification::make()
                            ->title('تعذر العثور على الملف المرفوع')
                            ->danger()
                            ->send();

                        return;
                    }

                    $absolute = Storage::disk('local')->path($path);

                    try {
                        $uploaded = new \Illuminate\Http\UploadedFile(
                            $absolute,
                            basename($path),
                            mime_content_type($absolute) ?: null,
                            null,
                            true,
                        );
                        $result = $excel->import($uploaded);
                    } catch (Throwable $exception) {
                        Notification::make()
                            ->title('فشل الاستيراد')
                            ->body($exception->getMessage())
                            ->danger()
                            ->send();

                        return;
                    } finally {
                        Storage::disk('local')->delete($path);
                    }

                    $body = "أُضيف {$result['created']} • حُدّث {$result['updated']} • تُخطّي {$result['skipped']}";
                    if ($result['errors'] !== []) {
                        $body .= "\n".implode("\n", array_slice($result['errors'], 0, 8));
                        if (count($result['errors']) > 8) {
                            $body .= "\n… و".(count($result['errors']) - 8).' أخطاء أخرى';
                        }
                    }

                    Notification::make()
                        ->title($result['errors'] === [] ? 'تم استيراد المنتجات' : 'اكتمل الاستيراد مع ملاحظات')
                        ->body($body)
                        ->color($result['errors'] === [] ? 'success' : 'warning')
                        ->send();
                }),
            CreateAction::make()->label('إضافة منتج'),
        ];
    }
}
