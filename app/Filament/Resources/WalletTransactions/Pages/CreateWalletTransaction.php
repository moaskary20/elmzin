<?php

namespace App\Filament\Resources\WalletTransactions\Pages;

use App\Enums\WalletTransactionType;
use App\Filament\Resources\WalletTransactionResource;
use App\Models\User;
use App\Services\WalletService;
use Filament\Resources\Pages\CreateRecord;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Auth;

class CreateWalletTransaction extends CreateRecord
{
    protected static string $resource = WalletTransactionResource::class;

    protected static ?string $title = 'حركة على محفظة عميل';

    protected function handleRecordCreation(array $data): Model
    {
        $type = $data['type'] instanceof WalletTransactionType
            ? $data['type']
            : WalletTransactionType::from($data['type']);

        return app(WalletService::class)->post(
            User::query()->findOrFail($data['user_id']),
            $type,
            (float) $data['amount'],
            $data['note'],
            createdBy: Auth::id(),
        );
    }

    protected function getCreatedNotificationTitle(): ?string
    {
        return 'تم تسجيل حركة المحفظة';
    }
}
