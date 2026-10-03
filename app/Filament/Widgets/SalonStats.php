<?php

namespace App\Filament\Widgets;

use App\Enums\BookingStatus;
use App\Enums\VerificationStatus;
use App\Models\Booking;
use App\Models\Coupon;
use App\Models\Salon;
use App\Models\Specialist;
use App\Models\User;
use Filament\Support\Icons\Heroicon;
use Filament\Widgets\StatsOverviewWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

class SalonStats extends StatsOverviewWidget
{
    protected static ?int $sort = 1;

    protected function getStats(): array
    {
        return [
            Stat::make('الصالونات', Salon::query()->count())
                ->description('المسجّلة على المنصة')
                ->descriptionIcon(Heroicon::OutlinedBuildingStorefront)
                ->chart([2, 3, 3, 4, 5, 6, Salon::query()->count()])
                ->color('primary'),
            Stat::make('الموثّقة', Salon::query()->where('verification_status', VerificationStatus::Verified)->count())
                ->description('صالونات ظهرت بشارة موثق')
                ->descriptionIcon(Heroicon::OutlinedCheckBadge)
                ->color('primary'),
            Stat::make('الأخصائيون', Specialist::query()->where('is_active', true)->count())
                ->description('داخل صالوناتهم')
                ->descriptionIcon(Heroicon::OutlinedUserGroup)
                ->color('primary'),
            Stat::make('حجوزات اليوم', Booking::query()
                ->whereDate('booked_on', today())
                ->where('status', '!=', BookingStatus::Cancelled)
                ->count())
                ->description('غير الملغاة')
                ->descriptionIcon(Heroicon::OutlinedClock)
                ->color('primary'),
            Stat::make('المستخدمون', User::query()->customers()->count())
                ->description('حسابات التطبيق')
                ->descriptionIcon(Heroicon::OutlinedUsers)
                ->color('primary'),
            Stat::make('كوبونات نشطة', Coupon::query()->where('is_active', true)->count())
                ->description('جاهزة للاستخدام')
                ->descriptionIcon(Heroicon::OutlinedTicket)
                ->color('primary'),
        ];
    }
}
