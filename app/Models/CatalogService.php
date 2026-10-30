<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class CatalogService extends Model
{
    protected $fillable = [
        'category_id',
        'name',
        'name_en',
        'description',
        'description_en',
        'price',
        'duration_minutes',
        'sort_order',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'price' => 'decimal:2',
            'duration_minutes' => 'integer',
            'sort_order' => 'integer',
            'is_active' => 'boolean',
        ];
    }

    protected static function booted(): void
    {
        static::updated(function (CatalogService $item): void {
            $payload = [];
            if ($item->wasChanged('name')) {
                $payload['name'] = $item->name;
            }
            if ($item->wasChanged('name_en')) {
                $payload['name_en'] = $item->name_en;
            }
            if ($item->wasChanged('description')) {
                $payload['description'] = $item->description;
            }
            if ($item->wasChanged('description_en')) {
                $payload['description_en'] = $item->description_en;
            }
            if ($payload !== []) {
                $item->services()->update($payload);
            }
        });
    }

    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class);
    }

    public function services(): HasMany
    {
        return $this->hasMany(Service::class);
    }
}
