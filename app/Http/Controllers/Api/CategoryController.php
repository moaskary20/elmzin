<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CatalogService;
use App\Models\Category;

class CategoryController extends Controller
{
    public function index()
    {
        $categories = Category::query()
            ->where('is_active', true)
            ->withCount(['listedSalons as salons_count' => fn ($query) => $query->where('salons.is_active', true)])
            ->orderBy('sort_order')
            ->orderBy('id')
            ->get()
            ->map(fn (Category $category) => [
                'id' => $category->id,
                'name' => $category->name,
                'name_en' => $category->name_en,
                'slug' => $category->slug,
                'description' => $category->description,
                'description_en' => $category->description_en,
                'salons_count' => $category->salons_count,
            ]);

        return response()->json(['data' => $categories]);
    }

    public function catalog()
    {
        $categories = Category::query()
            ->where('is_active', true)
            ->with(['catalogServices' => fn ($query) => $query
                ->where('is_active', true)
                ->orderBy('sort_order')
                ->orderBy('id')])
            ->orderBy('sort_order')
            ->orderBy('id')
            ->get()
            ->map(fn (Category $category) => [
                'id' => $category->id,
                'name' => $category->name,
                'name_en' => $category->name_en,
                'slug' => $category->slug,
                'services' => $category->catalogServices->map(fn (CatalogService $service) => [
                    'id' => $service->id,
                    'name' => $service->name,
                    'name_en' => $service->name_en,
                    'description' => $service->description,
                    'description_en' => $service->description_en,
                    'duration_minutes' => $service->duration_minutes,
                ])->values(),
            ]);

        return response()->json(['data' => $categories]);
    }
}
