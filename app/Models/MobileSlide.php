<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class MobileSlide extends Model
{
    protected $fillable = [
        'image',
        'title',
        'subtitle',
        'title_en',
        'subtitle_en',
        'sort_order',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
            'sort_order' => 'integer',
        ];
    }
}
