<?php

namespace App\Http\Controllers\Api;

use App\Enums\ShopOrderStatus;
use App\Http\Controllers\Controller;
use App\Models\ShopCategory;
use App\Models\ShopOrder;
use App\Models\ShopProduct;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpFoundation\BinaryFileResponse;

class ShopController extends Controller
{
    public function catalog(Request $request): JsonResponse
    {
        $categories = ShopCategory::query()
            ->where('is_active', true)
            ->with(['products' => fn ($query) => $query
                ->where('is_active', true)
                ->orderBy('sort_order')
                ->orderBy('id')])
            ->orderBy('sort_order')
            ->orderBy('id')
            ->get()
            ->map(fn (ShopCategory $category): array => [
                'id' => $category->id,
                'name' => $category->name,
                'name_en' => $category->name_en,
                'slug' => $category->slug,
                'description' => $category->description,
                'description_en' => $category->description_en,
                'image_url' => $this->categoryImageUrl($request, $category),
                'products' => $category->products->map(fn (ShopProduct $product): array => $this->productPayload($request, $product, $category))->values(),
            ]);

        return response()->json(['data' => $categories]);
    }

    public function products(Request $request): JsonResponse
    {
        $products = ShopProduct::query()
            ->where('is_active', true)
            ->with('category:id,name,slug')
            ->when(
                $request->filled('category_id'),
                fn ($query) => $query->where('shop_category_id', (int) $request->integer('category_id')),
            )
            ->orderBy('sort_order')
            ->orderBy('id')
            ->get()
            ->map(fn (ShopProduct $product): array => $this->productPayload($request, $product, $product->category));

        return response()->json(['data' => $products]);
    }

    public function show(Request $request, ShopProduct $product): JsonResponse
    {
        abort_unless($product->is_active, 404);
        $product->load('category:id,name,slug');

        return response()->json([
            'data' => $this->productPayload($request, $product, $product->category),
        ]);
    }

    public function placeOrder(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'customer_name' => ['required', 'string', 'max:255'],
            'customer_phone' => ['required', 'string', 'max:30'],
            'customer_address' => ['nullable', 'string', 'max:500'],
            'payment_method' => ['nullable', 'in:cash,card'],
            'card_last4' => ['nullable', 'required_if:payment_method,card', 'digits:4'],
            'notes' => ['nullable', 'string', 'max:1000'],
            'items' => ['required', 'array', 'min:1'],
            'items.*.product_id' => ['required', 'integer', 'exists:shop_products,id'],
            'items.*.quantity' => ['required', 'integer', 'min:1', 'max:100'],
        ], [
            'customer_name.required' => 'اكتب الاسم.',
            'customer_phone.required' => 'اكتب رقم الهاتف.',
            'items.required' => 'السلة فارغة.',
            'items.min' => 'السلة فارغة.',
            'payment_method.in' => 'طريقة الدفع غير معروفة.',
            'card_last4.required_if' => 'بيانات البطاقة غير مكتملة.',
            'card_last4.digits' => 'بيانات البطاقة غير صحيحة.',
        ]);

        $payment = $validated['payment_method'] ?? 'cash';
        $user = User::findByBearer($request->bearerToken());

        $order = DB::transaction(function () use ($validated, $payment, $user) {
            $lines = [];
            $total = 0.0;

            foreach ($validated['items'] as $row) {
                /** @var ShopProduct|null $product */
                $product = ShopProduct::query()
                    ->where('is_active', true)
                    ->lockForUpdate()
                    ->find((int) $row['product_id']);

                if ($product === null) {
                    throw ValidationException::withMessages([
                        'items' => 'أحد المنتجات غير متاح حالياً.',
                    ]);
                }

                $qty = (int) $row['quantity'];
                if ($product->stock < $qty) {
                    throw ValidationException::withMessages([
                        'items' => 'الكمية غير متاحة للمنتج: '.$product->name,
                    ]);
                }

                $lineTotal = round((float) $product->price * $qty, 2);
                $total += $lineTotal;
                $lines[] = [
                    'product' => $product,
                    'quantity' => $qty,
                    'line_total' => $lineTotal,
                ];
            }

            $order = ShopOrder::query()->create([
                'user_id' => $user?->id,
                'customer_name' => $validated['customer_name'],
                'customer_phone' => $validated['customer_phone'],
                'customer_address' => $validated['customer_address'] ?? null,
                'status' => ShopOrderStatus::Pending,
                'payment_method' => $payment,
                'card_last4' => $payment === 'card' ? ($validated['card_last4'] ?? null) : null,
                'total' => round($total, 2),
                'notes' => $validated['notes'] ?? null,
            ]);

            foreach ($lines as $line) {
                /** @var ShopProduct $product */
                $product = $line['product'];
                $order->items()->create([
                    'shop_product_id' => $product->id,
                    'product_name' => $product->name,
                    'price' => $product->price,
                    'quantity' => $line['quantity'],
                    'line_total' => $line['line_total'],
                ]);
                $product->forceFill([
                    'stock' => max(0, (int) $product->stock - (int) $line['quantity']),
                ])->save();
            }

            return $order->load('items');
        });

        return response()->json([
            'data' => [
                'id' => $order->id,
                'status' => $order->status->value,
                'payment_method' => $order->payment_method,
                'total' => (float) $order->total,
                'items' => $order->items->map(fn ($item): array => [
                    'product_id' => $item->shop_product_id,
                    'name' => $item->product_name,
                    'price' => (float) $item->price,
                    'quantity' => (int) $item->quantity,
                    'line_total' => (float) $item->line_total,
                ])->values(),
            ],
        ], 201);
    }

    public function productImage(ShopProduct $product): BinaryFileResponse
    {
        abort_unless($product->image && Storage::disk('public')->exists($product->image), 404);

        return response()->file(Storage::disk('public')->path($product->image));
    }

    public function categoryImage(ShopCategory $category): BinaryFileResponse
    {
        abort_unless($category->image && Storage::disk('public')->exists($category->image), 404);

        return response()->file(Storage::disk('public')->path($category->image));
    }

    private function productPayload(Request $request, ShopProduct $product, ?ShopCategory $category): array
    {
        return [
            'id' => $product->id,
            'name' => $product->name,
            'name_en' => $product->name_en,
            'description' => $product->description,
            'description_en' => $product->description_en,
            'price' => (float) $product->price,
            'compare_at_price' => $product->compare_at_price !== null ? (float) $product->compare_at_price : null,
            'stock' => (int) $product->stock,
            'image_url' => $this->productImageUrl($request, $product),
            'category' => [
                'id' => $category?->id ?? $product->shop_category_id,
                'name' => $category?->name ?? '',
                'name_en' => $category?->name_en ?? '',
                'slug' => $category?->slug ?? '',
            ],
        ];
    }

    private function productImageUrl(Request $request, ShopProduct $product): ?string
    {
        if (! $product->image || ! Storage::disk('public')->exists($product->image)) {
            return null;
        }

        return $request->getSchemeAndHttpHost().'/api/shop/products/'.$product->id.'/image';
    }

    private function categoryImageUrl(Request $request, ShopCategory $category): ?string
    {
        if (! $category->image || ! Storage::disk('public')->exists($category->image)) {
            return null;
        }

        return $request->getSchemeAndHttpHost().'/api/shop/categories/'.$category->id.'/image';
    }
}
