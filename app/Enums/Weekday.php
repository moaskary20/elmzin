<?php

namespace App\Enums;

use Filament\Support\Contracts\HasLabel;

enum Weekday: int implements HasLabel
{
    case Saturday = 6;
    case Sunday = 0;
    case Monday = 1;
    case Tuesday = 2;
    case Wednesday = 3;
    case Thursday = 4;
    case Friday = 5;

    public function getLabel(): string
    {
        return match ($this) {
            self::Saturday => 'السبت',
            self::Sunday => 'الأحد',
            self::Monday => 'الإثنين',
            self::Tuesday => 'الثلاثاء',
            self::Wednesday => 'الأربعاء',
            self::Thursday => 'الخميس',
            self::Friday => 'الجمعة',
        };
    }
}
