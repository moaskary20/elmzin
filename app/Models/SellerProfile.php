<?php

namespace App\Models;

use App\Enums\VerificationStatus;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Facades\Storage;

class SellerProfile extends Model
{
    protected $fillable = [
        'user_id',
        'national_id',
        'national_id_image',
        'commercial_register_image',
        'verification_status',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'verification_status' => VerificationStatus::class,
            'is_active' => 'boolean',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function hasNationalIdImage(): bool
    {
        return filled($this->national_id_image)
            && Storage::disk('public')->exists($this->national_id_image);
    }

    public function hasCommercialRegisterImage(): bool
    {
        return filled($this->commercial_register_image)
            && Storage::disk('public')->exists($this->commercial_register_image);
    }
}
