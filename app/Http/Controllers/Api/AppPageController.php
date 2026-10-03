<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AppPage;
use Illuminate\Http\JsonResponse;

class AppPageController extends Controller
{
    public function index(): JsonResponse
    {
        $pages = AppPage::query()
            ->where('is_active', true)
            ->with('blocks')
            ->orderBy('id')
            ->get()
            ->map(fn (AppPage $page) => [
                'slug' => $page->slug,
                'title' => $page->title,
                'title_en' => $page->title_en,
                'intro' => $page->intro,
                'intro_en' => $page->intro_en,
                'blocks' => $page->blocks->map(fn ($block) => [
                    'title' => $block->title,
                    'title_en' => $block->title_en,
                    'body' => $block->body,
                    'body_en' => $block->body_en,
                ])->values(),
            ]);

        return response()->json(['data' => $pages]);
    }
}
