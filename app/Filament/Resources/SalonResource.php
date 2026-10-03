<?php

namespace App\Filament\Resources;

use App\Enums\UserRole;
use App\Enums\VerificationStatus;
use App\Filament\Resources\Salons\Pages\CreateSalon;
use App\Filament\Resources\Salons\Pages\EditSalon;
use App\Filament\Resources\Salons\Pages\ListSalons;
use App\Filament\Resources\Salons\RelationManagers\BookingsRelationManager;
use App\Filament\Resources\Salons\RelationManagers\ReviewsRelationManager;
use App\Filament\Resources\Salons\RelationManagers\ServicesRelationManager;
use App\Filament\Resources\Salons\RelationManagers\SpecialistsRelationManager;
use App\Filament\Resources\Salons\RelationManagers\WorkingHoursRelationManager;
use App\Models\Salon;
use App\Models\User;
use BackedEnum;
use Filament\Actions\Action;
use Filament\Actions\BulkAction;
use Filament\Actions\BulkActionGroup;
use Filament\Actions\DeleteBulkAction;
use Filament\Actions\EditAction;
use Filament\Forms\Components\FileUpload;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
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
use Illuminate\Database\Eloquent\Collection;

class SalonResource extends Resource
{
    protected static ?string $model = Salon::class;

    protected static ?string $navigationLabel = 'الصالونات';

    protected static ?string $modelLabel = 'صالون';

    protected static ?string $pluralModelLabel = 'الصالونات';

    protected static ?string $recordTitleAttribute = 'name';

    protected static bool $hasTitleCaseModelLabel = false;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedBuildingStorefront;

    protected static ?int $navigationSort = 2;

    public static function form(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('بيانات الصالون')
                ->schema([
                    TextInput::make('name')
                        ->label('اسم الصالون')
                        ->required()
                        ->maxLength(255),
                    Select::make('category_id')
                        ->label('القسم')
                        ->relationship('category', 'name')
                        ->required()
                        ->native(false)
                        ->preload(),
                    TextInput::make('phone')
                        ->label('الهاتف')
                        ->tel(),
                    Toggle::make('is_active')
                        ->label('ظاهر للاختيار')
                        ->default(true),
                    Toggle::make('is_featured')
                        ->label('مكان مختار')
                        ->default(false),
                    Toggle::make('offers_home_service')
                        ->label('خدمة منزلية')
                        ->default(false),
                    Textarea::make('about')
                        ->label('نبذة')
                        ->rows(3)
                        ->columnSpanFull(),
                    FileUpload::make('image')
                        ->label('صورة الصالون')
                        ->image()
                        ->disk('public')
                        ->directory('salons')
                        ->columnSpanFull(),
                ])
                ->columns(2)
                ->columnSpanFull(),
            Section::make('بيانات تسجيل الدخول')
                ->description('الحساب الذي يدخل به الصالون إلى التطبيق.')
                ->icon(Heroicon::OutlinedKey)
                ->relationship('owner', condition: fn (?array $state): bool => filled($state['email'] ?? null))
                ->mutateRelationshipDataBeforeCreateUsing(fn (array $data): array => [
                    ...$data,
                    'name' => str($data['email'])->before('@')->toString(),
                    'role' => UserRole::Salon,
                ])
                ->schema([
                    TextInput::make('email')
                        ->label('البريد الإلكتروني')
                        ->email()
                        ->unique(User::class, 'email', ignoreRecord: true)
                        ->copyable()
                        ->maxLength(255),
                    TextInput::make('phone')
                        ->label('هاتف الحساب')
                        ->tel()
                        ->copyable()
                        ->maxLength(30),
                    TextInput::make('password')
                        ->label(fn (?User $record): string => $record ? 'كلمة مرور جديدة' : 'كلمة المرور')
                        ->password()
                        ->revealable()
                        ->minLength(6)
                        ->dehydrated(fn (?string $state): bool => filled($state))
                        ->helperText(fn (?User $record): ?string => $record
                            ? 'كلمة المرور محفوظة مشفرة ولا يمكن عرضها. اكتب كلمة جديدة لتغييرها، أو اتركها فارغة.'
                            : null),
                    Toggle::make('is_active')
                        ->label('الحساب مفعل')
                        ->default(true)
                        ->inline(false),
                ])
                ->columns(2)
                ->columnSpanFull(),
            Section::make('العنوان')
                ->schema([
                    TextInput::make('city')
                        ->label('المدينة')
                        ->required(),
                    TextInput::make('district')
                        ->label('الحي'),
                    TextInput::make('address')
                        ->label('العنوان')
                        ->required()
                        ->columnSpanFull(),
                    TextInput::make('latitude')
                        ->label('خط العرض')
                        ->numeric(),
                    TextInput::make('longitude')
                        ->label('خط الطول')
                        ->numeric(),
                ])
                ->columns(2)
                ->columnSpanFull(),
            Section::make('التوثيق والتقييم')
                ->schema([
                    Select::make('verification_status')
                        ->label('الحالة')
                        ->options(VerificationStatus::class)
                        ->default(VerificationStatus::Pending)
                        ->required()
                        ->native(false),
                    TextInput::make('rating_avg')
                        ->label('التقييم')
                        ->disabled()
                        ->dehydrated(false)
                        ->formatStateUsing(fn ($state): string => number_format((float) $state, 1).' / 5')
                        ->visible(fn (string $operation): bool => $operation === 'edit'),
                    TextInput::make('reviews_count')
                        ->label('عدد التقييمات')
                        ->disabled()
                        ->dehydrated(false)
                        ->visible(fn (string $operation): bool => $operation === 'edit'),
                ])
                ->columns(3)
                ->columnSpanFull(),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                ImageColumn::make('image')
                    ->label('الصورة')
                    ->disk('public')
                    ->circular(),
                TextColumn::make('name')
                    ->label('الصالون')
                    ->searchable()
                    ->sortable(),
                TextColumn::make('category.name')
                    ->label('القسم')
                    ->badge(),
                TextColumn::make('owner.email')
                    ->label('بيانات الدخول')
                    ->icon(Heroicon::OutlinedKey)
                    ->description(fn (Salon $record): ?string => $record->owner?->phone)
                    ->placeholder('بدون حساب')
                    ->copyable()
                    ->copyMessage('تم نسخ البريد')
                    ->searchable(),
                TextColumn::make('currentSubscription.plan_name')
                    ->label('الاشتراك')
                    ->badge()
                    ->color('warning')
                    ->description(fn (Salon $record): ?string => $record->currentSubscription
                        ? 'حتى '.$record->currentSubscription->ends_at->format('Y-m-d')
                        : null)
                    ->placeholder('بدون اشتراك'),
                TextColumn::make('city')
                    ->label('المدينة')
                    ->searchable(),
                TextColumn::make('address')
                    ->label('العنوان')
                    ->limit(32)
                    ->toggleable(),
                TextColumn::make('verification_status')
                    ->label('الحالة')
                    ->badge(),
                TextColumn::make('rating_avg')
                    ->label('التقييم')
                    ->formatStateUsing(fn ($state): string => number_format((float) $state, 1).' ★'),
                IconColumn::make('is_featured')
                    ->label('مختار')
                    ->boolean(),
                IconColumn::make('offers_home_service')
                    ->label('منزلي')
                    ->boolean(),
                IconColumn::make('is_active')
                    ->label('ظاهر')
                    ->boolean(),
            ])
            ->filters([
                SelectFilter::make('category_id')
                    ->label('القسم')
                    ->relationship('category', 'name'),
                SelectFilter::make('verification_status')
                    ->label('الحالة')
                    ->options(VerificationStatus::class),
            ])
            ->recordActions([
                Action::make('verify')
                    ->label('توثيق')
                    ->icon(Heroicon::OutlinedCheckBadge)
                    ->color('success')
                    ->requiresConfirmation()
                    ->modalHeading('توثيق الصالون')
                    ->modalDescription(fn (Salon $record): string => "سيظهر «{$record->name}» كصالون موثق في التطبيق.")
                    ->modalSubmitActionLabel('توثيق')
                    ->visible(fn (Salon $record): bool => $record->verification_status !== VerificationStatus::Verified)
                    ->action(fn (Salon $record) => $record->update(['verification_status' => VerificationStatus::Verified]))
                    ->successNotificationTitle('تم توثيق الصالون'),
                Action::make('reject')
                    ->label('رفض')
                    ->icon(Heroicon::OutlinedXCircle)
                    ->color('danger')
                    ->requiresConfirmation()
                    ->modalHeading('رفض التوثيق')
                    ->modalSubmitActionLabel('رفض')
                    ->visible(fn (Salon $record): bool => $record->verification_status === VerificationStatus::Pending)
                    ->action(fn (Salon $record) => $record->update(['verification_status' => VerificationStatus::Rejected]))
                    ->successNotificationTitle('تم رفض التوثيق'),
                EditAction::make(),
            ])
            ->toolbarActions([
                BulkActionGroup::make([
                    BulkAction::make('verifySelected')
                        ->label('توثيق المحدد')
                        ->icon(Heroicon::OutlinedCheckBadge)
                        ->color('success')
                        ->requiresConfirmation()
                        ->action(fn (Collection $records) => $records->each->update(['verification_status' => VerificationStatus::Verified]))
                        ->deselectRecordsAfterCompletion()
                        ->successNotificationTitle('تم توثيق الصالونات المحددة'),
                    DeleteBulkAction::make(),
                ]),
            ]);
    }

    public static function getRelations(): array
    {
        return [
            'hours' => WorkingHoursRelationManager::class,
            'services' => ServicesRelationManager::class,
            'specialists' => SpecialistsRelationManager::class,
            'bookings' => BookingsRelationManager::class,
            'reviews' => ReviewsRelationManager::class,
        ];
    }

    public static function getPages(): array
    {
        return [
            'index' => ListSalons::route('/'),
            'create' => CreateSalon::route('/create'),
            'edit' => EditSalon::route('/{record}/edit'),
        ];
    }
}
