<?php

namespace App\Enums;

use Filament\Support\Contracts\HasColor;
use Filament\Support\Contracts\HasLabel;

enum LoyaltyTransactionType: string implements HasColor, HasLabel
{
    case Earn = 'earn';
    case Redeem = 'redeem';
    case Adjust = 'adjust';
    case Expire = 'expire';

    public function getLabel(): string
    {
        return match ($this) {
            self::Earn => 'اكتساب',
            self::Redeem => 'استبدال',
            self::Adjust => 'تعديل',
            self::Expire => 'انتهاء',
        };
    }

    public function getColor(): string
    {
        return match ($this) {
            self::Earn => 'success',
            self::Redeem => 'warning',
            self::Adjust => 'info',
            self::Expire => 'danger',
        };
    }
}
