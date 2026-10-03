<?php

namespace App\Services;

use App\Enums\WalletTransactionType;
use App\Models\User;
use App\Models\WalletTransaction;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class WalletService
{
    /**
     * The amount is always positive; the type decides whether it adds or subtracts.
     */
    public function post(
        User $user,
        WalletTransactionType $type,
        float $amount,
        string $note,
        ?int $bookingId = null,
        ?int $createdBy = null,
    ): WalletTransaction {
        $amount = round($amount, 2);

        if ($amount <= 0) {
            throw ValidationException::withMessages([
                'amount' => 'أدخل مبلغاً أكبر من صفر.',
            ]);
        }

        return DB::transaction(function () use ($user, $type, $amount, $note, $bookingId, $createdBy): WalletTransaction {
            $locked = User::query()->whereKey($user->id)->lockForUpdate()->firstOrFail();
            $signed = $type->isCredit() ? $amount : -$amount;
            $balance = round((float) $locked->wallet_balance + $signed, 2);

            if ($balance < 0) {
                throw ValidationException::withMessages([
                    'amount' => 'الرصيد غير كافٍ. الرصيد الحالي '.number_format((float) $locked->wallet_balance, 2).' ج.م.',
                ]);
            }

            $locked->wallet_balance = $balance;
            $locked->save();
            $user->wallet_balance = $balance;

            return $locked->walletTransactions()->create([
                'type' => $type,
                'amount' => $signed,
                'balance_after' => $balance,
                'note' => $note,
                'booking_id' => $bookingId,
                'created_by' => $createdBy,
            ]);
        });
    }
}
