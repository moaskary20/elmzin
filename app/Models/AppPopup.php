<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class AppPopup extends Model
{
    protected $fillable = [
        'is_active',
        'title',
        'title_en',
        'body',
        'body_en',
        'button_label',
        'button_label_en',
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
        ];
    }

    public static function current(): self
    {
        return static::query()->firstOrCreate([], [
            'is_active' => false,
            'title' => 'مرحباً بك في المزين',
            'title_en' => 'Welcome to Elmzin',
            'body' => 'احجز كرسيك في أقرب صالون أو مركز تجميل خلال دقائق.',
            'body_en' => 'Book your chair at nearby salons and beauty centers in minutes.',
            'button_label' => 'حسناً',
            'button_label_en' => 'Got it',
        ]);
    }

    public function toApi(): ?array
    {
        if (! $this->is_active) {
            return null;
        }

        $title = trim((string) $this->title);
        $body = trim((string) $this->body);
        if ($title === '' || $body === '') {
            return null;
        }

        return [
            'id' => $this->id,
            'title' => $title,
            'title_en' => filled($this->title_en) ? trim((string) $this->title_en) : null,
            'body' => $body,
            'body_en' => filled($this->body_en) ? trim((string) $this->body_en) : null,
            'button_label' => filled($this->button_label) ? trim((string) $this->button_label) : 'حسناً',
            'button_label_en' => filled($this->button_label_en)
                ? trim((string) $this->button_label_en)
                : 'Got it',
            'updated_at' => optional($this->updated_at)?->toIso8601String(),
        ];
    }
}
