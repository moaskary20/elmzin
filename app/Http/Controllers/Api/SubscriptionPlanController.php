<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\SubscriptionPlan;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\BinaryFileResponse;

class SubscriptionPlanController extends Controller
{
    public function index(): JsonResponse
    {
        return response()->json([
            'data' => SubscriptionPlan::query()
                ->available()
                ->get()
                ->map(fn (SubscriptionPlan $plan): array => $plan->toApiArray())
                ->values(),
        ]);
    }

    public function image(SubscriptionPlan $plan): BinaryFileResponse
    {
        abort_unless($plan->is_active && $plan->hasImage(), 404);

        return response()->file(Storage::disk('public')->path($plan->image));
    }
}
