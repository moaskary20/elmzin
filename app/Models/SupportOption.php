<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

class SupportOption extends Model
{
    public const FIELDS = [
        'topic' => 'موضوع الرسالة',
        'related' => 'يتعلق بـ',
    ];

    protected $fillable = [
        'field',
        'label',
        'label_en',
        'is_other',
        'is_active',
        'sort_order',
    ];

    protected function casts(): array
    {
        return [
            'is_other' => 'boolean',
            'is_active' => 'boolean',
            'sort_order' => 'integer',
        ];
    }

    public function scopeActive(Builder $query): Builder
    {
        return $query->where('is_active', true)->orderBy('sort_order')->orderBy('id');
    }

    public function toApiArray(): array
    {
        return [
            'id' => $this->id,
            'label' => $this->label,
            'label_en' => $this->label_en,
            'is_other' => (bool) $this->is_other,
        ];
    }
}
