<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SalonMedia extends Model
{
    protected $table = 'salon_media';

    protected $fillable = [
        'salon_id',
        'type',
        'path',
        'sort_order',
    ];

    protected function casts(): array
    {
        return [
            'sort_order' => 'integer',
        ];
    }

    public function salon(): BelongsTo
    {
        return $this->belongsTo(Salon::class);
    }

    public function isVideo(): bool
    {
        return $this->type === 'video';
    }
}
