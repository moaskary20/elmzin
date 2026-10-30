<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use App\Enums\UserRole;
use App\Services\Notifier;
use Database\Factories\UserFactory;
use Filament\Models\Contracts\FilamentUser;
use Filament\Panel;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;

class User extends Authenticatable implements FilamentUser
{
    /** @use HasFactory<UserFactory> */
    use HasFactory, Notifiable;

    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'name',
        'name_en',
        'email',
        'phone',
        'password',
        'role',
        'is_active',
        'city',
        'city_en',
        'address',
        'address_en',
        'latitude',
        'longitude',
        'avatar',
        'notifications_enabled',
        'dark_mode',
        'locale',
        'loyalty_points',
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var list<string>
     */
    protected $hidden = [
        'password',
        'remember_token',
        'api_token',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'role' => UserRole::class,
            'is_active' => 'boolean',
            'loyalty_points' => 'integer',
            'wallet_balance' => 'decimal:2',
            'latitude' => 'float',
            'longitude' => 'float',
            'notifications_enabled' => 'boolean',
            'dark_mode' => 'boolean',
        ];
    }

    protected static function booted(): void
    {
        static::created(fn (User $user) => app(Notifier::class)->userCreated($user));

        static::saved(function (User $user): void {
            if ($user->role !== UserRole::Salon) {
                return;
            }

            $salon = $user->salon;
            if (! $salon) {
                return;
            }

            $salon->name = $user->name;
            if (filled($user->name_en)) {
                $salon->name_en = $user->name_en;
            }
            $salon->phone = $user->phone;
            if (filled($user->address)) {
                $salon->address = $user->address;
            }
            if (filled($user->city)) {
                $salon->city = $user->city;
            }
            if ($user->latitude !== null) {
                $salon->latitude = $user->latitude;
            }
            if ($user->longitude !== null) {
                $salon->longitude = $user->longitude;
            }

            if ($salon->isDirty()) {
                $salon->save();
            }
        });
    }

    public function toAccountArray(string $host): array
    {
        $nameEn = $this->name_en;
        if (! filled($nameEn) && $this->role === UserRole::Salon) {
            $nameEn = $this->salon?->name_en;
        }

        return [
            'id' => $this->id,
            'name' => $this->name,
            'name_en' => $nameEn,
            'email' => $this->email,
            'phone' => $this->phone,
            'address' => $this->address,
            'address_en' => $this->address_en,
            'city' => $this->city,
            'city_en' => $this->city_en,
            'latitude' => $this->latitude !== null ? (float) $this->latitude : null,
            'longitude' => $this->longitude !== null ? (float) $this->longitude : null,
            'role' => $this->role->value,
            'notifications' => (bool) $this->notifications_enabled,
            'dark_mode' => (bool) $this->dark_mode,
            'locale' => $this->locale ?: 'ar',
            'avatar_url' => $this->avatar ? $host.'/api/users/'.$this->id.'/avatar' : null,
            'wallet_balance' => (float) $this->wallet_balance,
            'loyalty_points' => (int) $this->loyalty_points,
        ];
    }

    public function canAccessPanel(Panel $panel): bool
    {
        return $this->role === UserRole::Admin && $this->is_active;
    }

    public function scopeCustomers(Builder $query): Builder
    {
        return $query->where('role', UserRole::Customer);
    }

    public function salon(): HasOne
    {
        return $this->hasOne(Salon::class);
    }

    public function bookings(): HasMany
    {
        return $this->hasMany(Booking::class);
    }

    public static function findByBearer(?string $plain): ?self
    {
        if (! is_string($plain) || $plain === '') {
            return null;
        }

        return static::query()
            ->where('api_token', hash('sha256', $plain))
            ->where('is_active', true)
            ->first();
    }

    public function loyaltyTransactions(): HasMany
    {
        return $this->hasMany(LoyaltyTransaction::class);
    }

    public function walletTransactions(): HasMany
    {
        return $this->hasMany(WalletTransaction::class);
    }

    public function couponRedemptions(): HasMany
    {
        return $this->hasMany(CouponRedemption::class);
    }
}
