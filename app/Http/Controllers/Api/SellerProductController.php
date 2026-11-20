<?php

namespace App\Http\Controllers\Api;

use App\Enums\UserRole;
use App\Http\Controllers\Controller;
use App\Models\ShopProduct;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;

class SellerProductController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $seller = $this->seller($request);

        $products = $seller->shopProducts()
            ->with('category:id,name,name_en,slug')
            ->orderByDesc('id')
            ->get()
            ->map(fn (ShopProduct $product): array => $this->payload($request, $product));

        return response()->json(['data' => $products]);
    }

    public function store(Request $request): JsonResponse
    {
        $seller = $this->sellerWithActivePlan($request);
        $data = $this->validated($request);

        $product = $seller->shopProducts()->create([
            ...$data,
            'user_id' => $seller->id,
            'is_active' => $request->boolean('is_active', true),
            'sort_order' => (int) ($data['sort_order'] ?? 0),
        ]);

        if ($request->hasFile('image')) {
            $product->image = $request->file('image')->store('shop/products', 'public');
            $product->save();
        }

        $product->load('category:id,name,name_en,slug');

        return response()->json(['data' => $this->payload($request, $product)], 201);
    }

    public function update(Request $request, ShopProduct $product): JsonResponse
    {
        $seller = $this->sellerWithActivePlan($request);
        abort_unless((int) $product->user_id === (int) $seller->id, 404);

        $data = $this->validated($request, partial: true);
        $product->fill($data);
        if ($request->exists('is_active')) {
            $product->is_active = $request->boolean('is_active');
        }

        if ($request->hasFile('image')) {
            if ($product->image) {
                Storage::disk('public')->delete($product->image);
            }
            $product->image = $request->file('image')->store('shop/products', 'public');
        }

        $product->save();
        $product->load('category:id,name,name_en,slug');

        return response()->json(['data' => $this->payload($request, $product)]);
    }

    public function destroy(Request $request, ShopProduct $product): JsonResponse
    {
        $seller = $this->seller($request);
        abort_unless((int) $product->user_id === (int) $seller->id, 404);

        if ($product->image) {
            Storage::disk('public')->delete($product->image);
        }
        $product->delete();

        return response()->json(['message' => 'تم حذف المنتج.']);
    }

    /**
     * @return array<string, mixed>
     */
    private function validated(Request $request, bool $partial = false): array
    {
        $required = $partial ? 'sometimes' : 'required';

        return $request->validate([
            'shop_category_id' => [
                $required,
                'integer',
                Rule::exists('shop_categories', 'id')->where('is_active', true),
            ],
            'name' => [$required, 'string', 'max:255'],
            'name_en' => ['sometimes', 'nullable', 'string', 'max:255'],
            'description' => ['sometimes', 'nullable', 'string'],
            'description_en' => ['sometimes', 'nullable', 'string'],
            'price' => [$required, 'numeric', 'min:0'],
            'compare_at_price' => ['sometimes', 'nullable', 'numeric', 'min:0'],
            'stock' => [$required, 'integer', 'min:0'],
            'sort_order' => ['sometimes', 'integer', 'min:0'],
            'is_active' => ['sometimes', 'boolean'],
            'image' => ['sometimes', 'nullable', 'image', 'max:5120'],
        ], [
            'shop_category_id.required' => 'اختر قسم المنتج.',
            'shop_category_id.exists' => 'القسم غير متاح.',
            'name.required' => 'اكتب اسم المنتج.',
            'price.required' => 'حدد السعر.',
            'stock.required' => 'حدد المخزون.',
            'image.image' => 'الملف يجب أن يكون صورة.',
        ]);
    }

    private function payload(Request $request, ShopProduct $product): array
    {
        $category = $product->category;

        return [
            'id' => $product->id,
            'name' => $product->name,
            'name_en' => $product->name_en,
            'description' => $product->description,
            'description_en' => $product->description_en,
            'price' => (float) $product->price,
            'compare_at_price' => $product->compare_at_price !== null ? (float) $product->compare_at_price : null,
            'stock' => (int) $product->stock,
            'is_active' => (bool) $product->is_active,
            'sort_order' => (int) $product->sort_order,
            'image_url' => $product->image && Storage::disk('public')->exists($product->image)
                ? $request->getSchemeAndHttpHost().'/api/shop/products/'.$product->id.'/image'
                : null,
            'seller_name' => $product->sellerName(),
            'category' => [
                'id' => $category?->id ?? $product->shop_category_id,
                'name' => $category?->name ?? '',
                'name_en' => $category?->name_en ?? '',
                'slug' => $category?->slug ?? '',
            ],
        ];
    }

    private function seller(Request $request): User
    {
        $user = User::findByBearer($request->bearerToken());
        abort_unless($user && $user->role === UserRole::Seller, 401);

        return $user;
    }

    private function sellerWithActivePlan(Request $request): User
    {
        $seller = $this->seller($request);
        abort_unless($seller->activeSellerSubscription() !== null, 403, 'اشتراكك غير فعّال.');

        return $seller;
    }
}
