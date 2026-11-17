<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AppPopup;
use Illuminate\Http\JsonResponse;

class AppPopupController extends Controller
{
    public function show(): JsonResponse
    {
        return response()->json([
            'data' => AppPopup::current()->toApi(),
        ]);
    }
}
