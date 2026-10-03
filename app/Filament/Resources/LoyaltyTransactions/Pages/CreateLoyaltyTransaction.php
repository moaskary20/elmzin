<?php

namespace App\Filament\Resources\LoyaltyTransactions\Pages;

use App\Filament\Resources\LoyaltyTransactionResource;
use App\Models\User;
use App\Services\OfferService;
use Filament\Resources\Pages\CreateRecord;
use Illuminate\Database\Eloquent\Model;

class CreateLoyaltyTransaction extends CreateRecord
{
    protected static string $resource = LoyaltyTransactionResource::class;

    protected static ?string $title = 'تعديل رصيد النقاط';

    protected function handleRecordCreation(array $data): Model
    {
        return app(OfferService::class)->adjust(
            User::query()->findOrFail($data['user_id']),
            (int) $data['points'],
            $data['note'],
        );
    }

    protected function getCreatedNotificationTitle(): ?string
    {
        return 'تم تسجيل حركة النقاط';
    }
}
