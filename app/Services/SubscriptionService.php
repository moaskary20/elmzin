<?php

namespace App\Services;

use App\Models\Salon;
use App\Models\SalonSubscription;
use App\Models\SubscriptionPlan;
use Carbon\CarbonInterface;

class SubscriptionService
{
    public function subscribe(
        Salon $salon,
        SubscriptionPlan $plan,
        ?CarbonInterface $startsAt = null,
        bool $termsAccepted = false,
    ): SalonSubscription {
        $start = $startsAt ?? now();

        return $salon->subscriptions()->create([
            'subscription_plan_id' => $plan->id,
            'plan_name' => $plan->name,
            'price' => $plan->price,
            'starts_at' => $start,
            'ends_at' => $plan->endsFrom($start),
            'status' => 'active',
            'terms_accepted_at' => $termsAccepted ? now() : null,
        ]);
    }

    /**
     * Starts the next period when the current one ends, so renewing early loses no days.
     */
    public function renew(Salon $salon, SubscriptionPlan $plan): SalonSubscription
    {
        $current = $salon->currentSubscription()->first();
        $start = $current?->ends_at && $current->ends_at->isFuture() ? $current->ends_at : now();

        return $this->subscribe($salon, $plan, $start, true);
    }

    public function limitReached(Salon $salon, string $what): ?string
    {
        $plan = $salon->currentSubscription()->with('plan')->first()?->plan;

        if (! $plan) {
            return null;
        }

        $limit = $what === 'services' ? $plan->max_services : $plan->max_specialists;

        if (! $limit) {
            return null;
        }

        $count = $what === 'services' ? $salon->services()->count() : $salon->specialists()->count();

        if ($count < $limit) {
            return null;
        }

        $label = $what === 'services' ? 'خدمة' : 'أخصائي';

        return "وصلت للحد الأقصى في {$plan->name} ({$limit} {$label}). رقِّ باقتك لإضافة المزيد.";
    }
}
