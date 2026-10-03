<?php

namespace App\Enums;

use Filament\Support\Contracts\HasLabel;

enum UserRole: string implements HasLabel
{
    case Admin = 'admin';
    case Customer = 'customer';
    case Salon = 'salon';

    public function getLabel(): string
    {
        return match ($this) {
            self::Admin => 'مدير',
            self::Customer => 'عميل',
            self::Salon => 'صالون',
        };
    }
}
