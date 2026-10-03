<?php

namespace App\Filament\Resources\Salons\Pages;

use App\Enums\VerificationStatus;
use App\Filament\Resources\SalonResource;
use App\Models\Salon;
use Filament\Actions\CreateAction;
use Filament\Resources\Pages\ListRecords;
use Filament\Schemas\Components\Tabs\Tab;
use Filament\Support\Icons\Heroicon;
use Illuminate\Database\Eloquent\Builder;

class ListSalons extends ListRecords
{
    protected static string $resource = SalonResource::class;

    protected function getHeaderActions(): array
    {
        return [
            CreateAction::make(),
        ];
    }

    public function getTabs(): array
    {
        $tabs = [
            'verified' => Tab::make('الصالونات الموثقة')
                ->icon(Heroicon::OutlinedCheckBadge)
                ->badge($this->countOf(VerificationStatus::Verified))
                ->badgeColor('success')
                ->modifyQueryUsing(fn (Builder $query): Builder => $query->where('verification_status', VerificationStatus::Verified)),
            'pending' => Tab::make('في انتظار التوثيق')
                ->icon(Heroicon::OutlinedClock)
                ->badge($this->countOf(VerificationStatus::Pending))
                ->badgeColor('warning')
                ->modifyQueryUsing(fn (Builder $query): Builder => $query->where('verification_status', VerificationStatus::Pending)),
        ];

        if ($this->countOf(VerificationStatus::Rejected) > 0) {
            $tabs['rejected'] = Tab::make('المرفوضة')
                ->icon(Heroicon::OutlinedXCircle)
                ->badge($this->countOf(VerificationStatus::Rejected))
                ->badgeColor('danger')
                ->modifyQueryUsing(fn (Builder $query): Builder => $query->where('verification_status', VerificationStatus::Rejected));
        }

        return $tabs;
    }

    public function getDefaultActiveTab(): string|int|null
    {
        return 'verified';
    }

    private function countOf(VerificationStatus $status): int
    {
        return Salon::query()->where('verification_status', $status)->count();
    }
}
