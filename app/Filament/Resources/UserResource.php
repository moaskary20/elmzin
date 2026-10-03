<?php

namespace App\Filament\Resources;

use App\Enums\UserRole;
use App\Filament\Resources\Users\Pages\CreateUser;
use App\Filament\Resources\Users\Pages\EditUser;
use App\Filament\Resources\Users\Pages\ListUsers;
use App\Filament\Resources\Users\RelationManagers\BookingsRelationManager;
use App\Filament\Resources\Users\RelationManagers\CouponRedemptionsRelationManager;
use App\Filament\Resources\Users\RelationManagers\LoyaltyTransactionsRelationManager;
use App\Filament\Resources\Users\RelationManagers\WalletTransactionsRelationManager;
use App\Models\User;
use BackedEnum;
use Filament\Actions\BulkActionGroup;
use Filament\Actions\DeleteBulkAction;
use Filament\Actions\EditAction;
use Filament\Forms\Components\FileUpload;
use Filament\Forms\Components\Placeholder;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\ImageColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

class UserResource extends Resource
{
    protected static ?string $model = User::class;

    protected static ?string $navigationLabel = 'المستخدمون';

    protected static ?string $modelLabel = 'مستخدم';

    protected static ?string $pluralModelLabel = 'المستخدمون';

    protected static string|\UnitEnum|null $navigationGroup = 'المستخدمون';

    protected static ?string $recordTitleAttribute = 'name';

    protected static bool $hasTitleCaseModelLabel = false;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedUsers;

    protected static ?int $navigationSort = 1;

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('بيانات المستخدم')
                ->description('حساب عميل أو صالون من التطبيق. الدخول إلى لوحة الإدارة يبقى للمدير فقط.')
                ->schema([
                    FileUpload::make('avatar')
                        ->label('الصورة')
                        ->image()
                        ->disk('public')
                        ->directory('avatars')
                        ->avatar()
                        ->columnSpanFull(),
                    TextInput::make('name')
                        ->label('الاسم')
                        ->required()
                        ->maxLength(255),
                    TextInput::make('phone')
                        ->label('الهاتف')
                        ->tel()
                        ->required()
                        ->unique(ignoreRecord: true)
                        ->maxLength(30),
                    TextInput::make('email')
                        ->label('البريد')
                        ->email()
                        ->required()
                        ->unique(ignoreRecord: true)
                        ->maxLength(255),
                    Placeholder::make('account_role')
                        ->label('نوع الحساب')
                        ->content(fn (?User $record): string => $record?->role?->getLabel() ?? 'عميل'),
                    TextInput::make('city')
                        ->label('المدينة')
                        ->maxLength(255),
                    TextInput::make('address')
                        ->label('العنوان')
                        ->maxLength(255)
                        ->columnSpanFull(),
                    TextInput::make('password')
                        ->label('كلمة المرور')
                        ->password()
                        ->revealable()
                        ->required(fn (string $operation): bool => $operation === 'create')
                        ->dehydrated(fn (?string $state): bool => filled($state))
                        ->minLength(8)
                        ->helperText('في التعديل اتركها فارغة للإبقاء على كلمة المرور الحالية.'),
                    Toggle::make('is_active')
                        ->label('يمكنه الحجز')
                        ->default(true),
                    Toggle::make('notifications_enabled')
                        ->label('الإشعارات')
                        ->default(true),
                    Toggle::make('dark_mode')
                        ->label('الوضع الداكن')
                        ->default(true),
                    Select::make('locale')
                        ->label('اللغة')
                        ->options([
                            'ar' => 'العربية',
                            'en' => 'English',
                        ])
                        ->default('ar')
                        ->required(),
                    Placeholder::make('loyalty_balance')
                        ->label('رصيد نقاط الولاء')
                        ->content(fn (?User $record): string => (string) ($record->loyalty_points ?? 0)),
                    Placeholder::make('wallet_balance_view')
                        ->label('رصيد المحفظة')
                        ->content(fn (?User $record): string => number_format((float) ($record->wallet_balance ?? 0), 2).' ج.م'),
                ])
                ->columns(2)
                ->columnSpanFull(),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                ImageColumn::make('avatar')
                    ->label('الصورة')
                    ->disk('public')
                    ->circular(),
                TextColumn::make('name')
                    ->label('الاسم')
                    ->searchable(),
                TextColumn::make('role')
                    ->label('النوع')
                    ->formatStateUsing(function (UserRole|string|null $state): string {
                        if ($state instanceof UserRole) {
                            return $state->getLabel();
                        }

                        return UserRole::tryFrom((string) $state)?->getLabel() ?? '—';
                    }),
                TextColumn::make('phone')
                    ->label('الهاتف')
                    ->searchable(),
                TextColumn::make('email')
                    ->label('البريد')
                    ->searchable()
                    ->toggleable(),
                TextColumn::make('address')
                    ->label('العنوان')
                    ->limit(32)
                    ->placeholder('—')
                    ->toggleable(),
                TextColumn::make('locale')
                    ->label('اللغة')
                    ->formatStateUsing(fn (?string $state): string => $state === 'en' ? 'English' : 'العربية'),
                IconColumn::make('notifications_enabled')
                    ->label('الإشعارات')
                    ->boolean(),
                IconColumn::make('dark_mode')
                    ->label('داكن')
                    ->boolean(),
                TextColumn::make('loyalty_points')
                    ->label('النقاط')
                    ->sortable(),
                TextColumn::make('wallet_balance')
                    ->label('المحفظة')
                    ->formatStateUsing(fn ($state): string => number_format((float) $state, 2).' ج.م')
                    ->sortable(),
                TextColumn::make('bookings_count')
                    ->label('الحجوزات')
                    ->sortable(),
                IconColumn::make('is_active')
                    ->label('نشط')
                    ->boolean(),
            ])
            ->defaultSort('id', 'desc')
            ->filters([
                SelectFilter::make('role')
                    ->label('النوع')
                    ->options([
                        UserRole::Customer->value => 'عميل',
                        UserRole::Salon->value => 'صالون',
                    ]),
                SelectFilter::make('is_active')
                    ->label('الحالة')
                    ->options([
                        1 => 'نشط',
                        0 => 'موقوف',
                    ]),
            ])
            ->recordActions([
                EditAction::make(),
            ])
            ->toolbarActions([
                BulkActionGroup::make([
                    DeleteBulkAction::make(),
                ]),
            ]);
    }

    public static function getEloquentQuery(): Builder
    {
        return parent::getEloquentQuery()
            ->whereIn('role', [UserRole::Customer, UserRole::Salon])
            ->withCount('bookings');
    }

    public static function getRelations(): array
    {
        return [
            'bookings' => BookingsRelationManager::class,
            'points' => LoyaltyTransactionsRelationManager::class,
            'wallet' => WalletTransactionsRelationManager::class,
            'coupons' => CouponRedemptionsRelationManager::class,
        ];
    }

    public static function getPages(): array
    {
        return [
            'index' => ListUsers::route('/'),
            'create' => CreateUser::route('/create'),
            'edit' => EditUser::route('/{record}/edit'),
        ];
    }
}
