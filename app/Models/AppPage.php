<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class AppPage extends Model
{
    protected $fillable = [
        'slug',
        'title',
        'title_en',
        'intro',
        'intro_en',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
        ];
    }

    public function blocks(): HasMany
    {
        return $this->hasMany(AppPageBlock::class)->orderBy('sort_order')->orderBy('id');
    }
}
