<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\MobileSlide;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class MobileSlideController extends Controller
{
    public function index(Request $request)
    {
        $slides = MobileSlide::query()
            ->where('is_active', true)
            ->orderBy('sort_order')
            ->orderBy('id')
            ->get()
            ->map(fn (MobileSlide $slide) => [
                'id' => $slide->id,
                'image_url' => $request->getSchemeAndHttpHost().'/api/slides/'.$slide->id.'/image',
                'title' => $slide->title,
                'subtitle' => $slide->subtitle,
                'title_en' => $slide->title_en,
                'subtitle_en' => $slide->subtitle_en,
            ]);

        return response()->json(['data' => $slides]);
    }

    public function image(MobileSlide $slide)
    {
        abort_unless($slide->is_active && Storage::disk('public')->exists($slide->image), 404);

        return response()->file(Storage::disk('public')->path($slide->image));
    }
}
