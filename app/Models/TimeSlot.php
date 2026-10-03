<?php

namespace App\Models;

use App\Enums\Weekday;
use Carbon\Carbon;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class TimeSlot extends Model
{
    protected $fillable = [
        'specialist_id',
        'day_of_week',
        'starts_at',
        'ends_at',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'day_of_week' => Weekday::class,
            'is_active' => 'boolean',
        ];
    }

    public function specialist(): BelongsTo
    {
        return $this->belongsTo(Specialist::class);
    }

    public function clock(string $attribute): string
    {
        return Carbon::parse($this->{$attribute})->format('H:i');
    }

    public function getLabelAttribute(): string
    {
        return $this->clock('starts_at').' — '.$this->clock('ends_at');
    }
}
