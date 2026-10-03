<?php

namespace App\Enums;

use Filament\Support\Contracts\HasColor;
use Filament\Support\Contracts\HasLabel;

enum WalletTransactionType: string implements HasColor, HasLabel
{
    case Deposit = 'deposit';
    case Refund = 'refund';
    case Reward = 'reward';
    case Payment = 'payment';
    case Withdrawal = 'withdrawal';

    public function getLabel(): string
    {
        return match ($this) {
            self::Deposit => 'شحن رصيد',
            self::Refund => 'استرداد',
            self::Reward => 'مكافأة',
            self::Payment => 'دفع حجز',
            self::Withdrawal => 'خصم',
        };
    }

    public function getColor(): string
    {
        return match ($this) {
            self::Deposit => 'success',
            self::Refund => 'info',
            self::Reward => 'warning',
            self::Payment => 'gray',
            self::Withdrawal => 'danger',
        };
    }

    public function isCredit(): bool
    {
        return in_array($this, [self::Deposit, self::Refund, self::Reward], true);
    }
}
