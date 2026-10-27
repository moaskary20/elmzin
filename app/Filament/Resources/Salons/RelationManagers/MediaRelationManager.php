<?php

namespace App\Filament\Resources\Salons\RelationManagers;

use App\Models\Salon;
use App\Models\SalonMedia;
use Filament\Actions\CreateAction;
use Filament\Actions\DeleteAction;
use Filament\Actions\EditAction;
use Filament\Forms\Components\FileUpload;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Resources\RelationManagers\RelationManager;
use Filament\Schemas\Schema;
use Filament\Tables\Columns\ImageColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\ValidationException;

class MediaRelationManager extends RelationManager
{
    protected static string $relationship = 'media';

    protected static ?string $title = 'سليدر الصور والفيديو';

    protected static ?string $modelLabel = 'وسيط';

    protected static ?string $pluralModelLabel = 'وسائط';

    protected static bool $isLazy = false;

    public function form(Schema $schema): Schema
    {
        return $schema->components([
            Select::make('type')
                ->label('النوع')
                ->options([
                    'image' => 'صورة',
                    'video' => 'فيديو',
                ])
                ->required()
                ->native(false)
                ->live()
                ->default('image'),
            FileUpload::make('path')
                ->label(fn (callable $get): string => $get('type') === 'video' ? 'ملف الفيديو' : 'الصورة')
                ->disk('public')
                ->directory(fn (callable $get): string => $get('type') === 'video' ? 'salons/videos' : 'salons')
                ->acceptedFileTypes(fn (callable $get): array => $get('type') === 'video'
                    ? ['video/mp4', 'video/quicktime', 'video/webm', 'video/x-m4v']
                    : ['image/jpeg', 'image/png', 'image/webp', 'image/gif'])
                ->maxSize(fn (callable $get): int => $get('type') === 'video' ? 51200 : 6144)
                ->required()
                ->openable()
                ->downloadable()
                ->columnSpanFull(),
            TextInput::make('sort_order')
                ->label('الترتيب')
                ->numeric()
                ->default(0)
                ->required()
                ->minValue(0),
        ]);
    }

    public function table(Table $table): Table
    {
        return $table
            ->description('الصور والفيديو التي تظهر في سليدر صفحة الصالون داخل التطبيق. حتى ٨ صور وفيديو واحد.')
            ->reorderable('sort_order')
            ->defaultSort('sort_order')
            ->columns([
                ImageColumn::make('path')
                    ->label('معاينة')
                    ->disk('public')
                    ->square()
                    ->height(56),
                TextColumn::make('type')
                    ->label('النوع')
                    ->badge()
                    ->formatStateUsing(fn (?string $state): string => $state === 'video' ? 'فيديو' : 'صورة')
                    ->color(fn (?string $state): string => $state === 'video' ? 'info' : 'success'),
                TextColumn::make('file')
                    ->label('الملف')
                    ->state(fn (SalonMedia $record): string => basename((string) $record->path))
                    ->toggleable(),
                TextColumn::make('sort_order')
                    ->label('الترتيب')
                    ->sortable(),
            ])
            ->headerActions([
                CreateAction::make()
                    ->label('إضافة للسليدر')
                    ->mutateDataUsing(fn (array $data): array => $this->guardLimits($data))
                    ->after(fn (SalonMedia $record) => $this->syncCover($record)),
            ])
            ->recordActions([
                EditAction::make()
                    ->mutateDataUsing(fn (array $data, SalonMedia $record): array => $this->guardLimits($data, $record))
                    ->after(fn (SalonMedia $record) => $this->syncCover($record)),
                DeleteAction::make()
                    ->after(function (Model $record): void {
                        if ($record instanceof SalonMedia && filled($record->path)) {
                            Storage::disk('public')->delete($record->path);
                        }
                        $this->syncCoverAfterDelete();
                    }),
            ]);
    }

    /**
     * @param  array<string, mixed>  $data
     * @return array<string, mixed>
     */
    private function guardLimits(array $data, ?SalonMedia $current = null): array
    {
        /** @var Salon $salon */
        $salon = $this->getOwnerRecord();
        $type = $data['type'] ?? 'image';

        $images = $salon->media()
            ->where('type', 'image')
            ->when($current, fn ($query) => $query->whereKeyNot($current->getKey()))
            ->count();
        $videos = $salon->media()
            ->where('type', 'video')
            ->when($current, fn ($query) => $query->whereKeyNot($current->getKey()))
            ->count();

        if ($type === 'image' && $images >= 8) {
            throw ValidationException::withMessages([
                'path' => 'يمكنك رفع ٨ صور كحد أقصى في السليدر.',
            ]);
        }

        if ($type === 'video' && $videos >= 1) {
            throw ValidationException::withMessages([
                'path' => 'يمكنك رفع فيديو واحد فقط في السليدر.',
            ]);
        }

        if (! isset($data['sort_order']) || $data['sort_order'] === '' || $data['sort_order'] === null) {
            $data['sort_order'] = (int) $salon->media()->max('sort_order') + 1;
        }

        return $data;
    }

    private function syncCover(SalonMedia $record): void
    {
        if ($record->type !== 'image') {
            return;
        }

        /** @var Salon $salon */
        $salon = $this->getOwnerRecord();
        if (blank($salon->image) || $salon->image === $record->path) {
            $salon->forceFill(['image' => $record->path])->save();
        }
    }

    private function syncCoverAfterDelete(): void
    {
        /** @var Salon $salon */
        $salon = $this->getOwnerRecord()->fresh('media');
        $firstImage = $salon->media->firstWhere('type', 'image');
        $salon->forceFill([
            'image' => $firstImage?->path,
        ])->save();
    }
}
