<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AppNotification;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class NotificationController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $user = $this->account($request);

        $rows = AppNotification::query()
            ->where('user_id', $user->id)
            ->latest('id')
            ->limit(100)
            ->get()
            ->map(fn (AppNotification $item): array => $this->present($item))
            ->values();

        return response()->json([
            'data' => $rows,
            'unread' => $this->unread($user),
        ]);
    }

    public function read(Request $request, AppNotification $notification): JsonResponse
    {
        $user = $this->account($request);

        abort_unless($notification->user_id === $user->id, response()->json([
            'message' => 'الإشعار غير موجود.',
        ], 404));

        if (! $notification->read_at) {
            $notification->forceFill(['read_at' => now()])->save();
        }

        return response()->json([
            'data' => $this->present($notification),
            'unread' => $this->unread($user),
        ]);
    }

    public function readAll(Request $request): JsonResponse
    {
        $user = $this->account($request);

        AppNotification::query()
            ->where('user_id', $user->id)
            ->whereNull('read_at')
            ->update(['read_at' => now()]);

        return response()->json(['unread' => 0]);
    }

    private function present(AppNotification $item): array
    {
        return [
            'id' => $item->id,
            'type' => $item->type,
            'title' => $item->title,
            'body' => $item->body,
            'data' => $item->data ?? (object) [],
            'read' => $item->read_at !== null,
            'created_at' => $item->created_at?->toIso8601String(),
        ];
    }

    private function unread(User $user): int
    {
        return AppNotification::query()
            ->where('user_id', $user->id)
            ->whereNull('read_at')
            ->count();
    }

    private function account(Request $request): User
    {
        $user = User::findByBearer($request->bearerToken());

        abort_if($user === null, response()->json([
            'message' => 'يلزم تسجيل الدخول.',
        ], 401));

        return $user;
    }
}
