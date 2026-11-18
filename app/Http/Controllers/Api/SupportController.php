<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\SupportOption;
use App\Models\SupportTicket;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SupportController extends Controller
{
    public function form(): JsonResponse
    {
        $options = SupportOption::query()->active()->get()->groupBy('field');

        return response()->json([
            'topic_label' => 'موضوع الرسالة',
            'topic_label_en' => 'Message topic',
            'related_label' => 'يتعلق بـ',
            'related_label_en' => 'Related to',
            'success_message' => 'تم استلام رسالتك. سيتواصل معك فريق الدعم خلال 48 ساعة.',
            'success_message_en' => 'Your message was received. Our support team will contact you within 48 hours.',
            'topics' => ($options->get('topic') ?? collect())->values()->map->toApiArray(),
            'related' => ($options->get('related') ?? collect())->values()->map->toApiArray(),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $user = User::findByBearer($request->bearerToken());
        if (! $user) {
            return response()->json(['message' => 'Unauthorized'], 401);
        }

        $data = $request->validate([
            'topic_option_id' => ['required', 'integer', 'exists:support_options,id'],
            'topic_custom' => ['nullable', 'string', 'max:500'],
            'related_option_id' => ['required', 'integer', 'exists:support_options,id'],
            'related_custom' => ['nullable', 'string', 'max:500'],
            'message' => ['nullable', 'string', 'max:2000'],
        ]);

        $topic = SupportOption::query()
            ->where('field', 'topic')
            ->where('is_active', true)
            ->findOrFail($data['topic_option_id']);
        $related = SupportOption::query()
            ->where('field', 'related')
            ->where('is_active', true)
            ->findOrFail($data['related_option_id']);

        if ($topic->is_other && blank($data['topic_custom'] ?? null)) {
            return response()->json([
                'message' => 'The given data was invalid.',
                'errors' => ['topic_custom' => ['اكتب تفاصيل الموضوع.']],
            ], 422);
        }

        if ($related->is_other && blank($data['related_custom'] ?? null)) {
            return response()->json([
                'message' => 'The given data was invalid.',
                'errors' => ['related_custom' => ['اكتب تفاصيل ما يتعلق به الطلب.']],
            ], 422);
        }

        SupportTicket::query()->create([
            'user_id' => $user->id,
            'topic_option_id' => $topic->id,
            'topic_label' => $topic->label,
            'topic_custom' => $topic->is_other ? trim((string) $data['topic_custom']) : null,
            'related_option_id' => $related->id,
            'related_label' => $related->label,
            'related_custom' => $related->is_other ? trim((string) $data['related_custom']) : null,
            'message' => filled($data['message'] ?? null) ? trim((string) $data['message']) : null,
            'status' => 'new',
        ]);

        return response()->json([
            'message' => 'تم استلام رسالتك. سيتواصل معك فريق الدعم خلال 48 ساعة.',
            'message_en' => 'Your message was received. Our support team will contact you within 48 hours.',
        ], 201);
    }
}
