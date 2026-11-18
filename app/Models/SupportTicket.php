<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SupportTicket extends Model
{
    public const STATUSES = [
        'new' => 'جديدة',
        'in_progress' => 'قيد المتابعة',
        'closed' => 'مغلقة',
    ];

    protected $fillable = [
        'user_id',
        'topic_option_id',
        'topic_label',
        'topic_custom',
        'related_option_id',
        'related_label',
        'related_custom',
        'message',
        'status',
        'read_at',
    ];

    protected function casts(): array
    {
        return [
            'read_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function topicOption(): BelongsTo
    {
        return $this->belongsTo(SupportOption::class, 'topic_option_id');
    }

    public function relatedOption(): BelongsTo
    {
        return $this->belongsTo(SupportOption::class, 'related_option_id');
    }

    public function statusLabel(): string
    {
        return self::STATUSES[$this->status] ?? $this->status;
    }
}
