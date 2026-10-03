<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Category extends Model
{
    protected $fillable = [
        'name',
        'slug',
        'description',
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

    public function salons(): HasMany
    {
        return $this->hasMany(Salon::class);
    }

    public function catalogServices(): HasMany
    {
        return $this->hasMany(CatalogService::class);
    }
}
