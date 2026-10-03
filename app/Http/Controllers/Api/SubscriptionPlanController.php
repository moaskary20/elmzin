<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\SubscriptionPlan;
use Illuminate\Http\JsonResponse;

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
}
