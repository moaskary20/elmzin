<?php

namespace App\Enums;

use Filament\Support\Contracts\HasColor;
use Filament\Support\Contracts\HasLabel;

enum CouponType: string implements HasColor, HasLabel
{
    case Percent = 'percent';
    case Fixed = 'fixed';

    public function getLabel(): string
    {
        return match ($this) {
            self::Percent => 'نسبة مئوية',
            self::Fixed => 'مبلغ ثابت',
        };
    }

    public function getColor(): string
    {
        return match ($this) {
            self::Percent => 'warning',
            self::Fixed => 'info',
        };
    }
}
