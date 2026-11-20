<?php

namespace App\Filament\Resources\SellerProfiles\Pages;

use App\Filament\Resources\SellerProfileResource;
use Filament\Resources\Pages\EditRecord;

class EditSellerProfile extends EditRecord
{
    protected static string $resource = SellerProfileResource::class;

    protected function mutateFormDataBeforeFill(array $data): array
    {
        $data['user'] = [
            'name' => $this->record->user?->name,
            'phone' => $this->record->user?->phone,
            'email' => $this->record->user?->email,
        ];

        return $data;
    }
}
