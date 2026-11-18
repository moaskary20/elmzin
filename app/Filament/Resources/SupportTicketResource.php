<?php

namespace App\Filament\Resources;

use App\Filament\Resources\SupportTickets\Pages\ListSupportTickets;
use App\Filament\Resources\SupportTickets\Pages\ViewSupportTicket;
use App\Models\SupportTicket;
use BackedEnum;
use Filament\Actions\Action;
use Filament\Actions\ViewAction;
use Filament\Infolists\Components\TextEntry;
use Filament\Resources\Resource;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

class SupportTicketResource extends Resource
{
    protected static ?string $model = SupportTicket::class;

    protected static ?string $navigationLabel = 'رسائل الدعم';

    protected static ?string $modelLabel = 'رسالة دعم';

    protected static ?string $pluralModelLabel = 'رسائل الدعم';

    protected static bool $hasTitleCaseModelLabel = false;

    protected static string|\UnitEnum|null $navigationGroup = 'تطبيق الموبايل';

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedInbox;

    protected static ?int $navigationSort = 5;

    public static function canCreate(): bool
    {
        return false;
    }

    public static function infolist(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('بيانات الرسالة')
                ->schema([
                    TextEntry::make('user.name')->label('العميل'),
                    TextEntry::make('user.phone')->label('الهاتف'),
                    TextEntry::make('user.email')->label('البريد'),
                    TextEntry::make('status')
                        ->label('الحالة')
                        ->formatStateUsing(fn (SupportTicket $record): string => $record->statusLabel()),
                    TextEntry::make('topic_label')->label('موضوع الرسالة'),
                    TextEntry::make('topic_custom')->label('تفاصيل الموضوع')->placeholder('—'),
                    TextEntry::make('related_label')->label('يتعلق بـ'),
                    TextEntry::make('related_custom')->label('تفاصيل المتعلق')->placeholder('—'),
                    TextEntry::make('message')->label('الرسالة')->placeholder('—')->columnSpanFull(),
                    TextEntry::make('created_at')->label('تاريخ الإرسال')->dateTime('Y-m-d H:i'),
                ])
                ->columns(2)
                ->columnSpanFull(),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('user.name')
                    ->label('العميل')
                    ->searchable()
                    ->description(fn (SupportTicket $record): string => $record->user?->phone ?? ''),
                TextColumn::make('topic_label')
                    ->label('الموضوع')
                    ->description(fn (SupportTicket $record): ?string => $record->topic_custom)
                    ->wrap(),
                TextColumn::make('related_label')
                    ->label('يتعلق بـ')
                    ->description(fn (SupportTicket $record): ?string => $record->related_custom),
                TextColumn::make('status')
                    ->label('الحالة')
                    ->badge()
                    ->formatStateUsing(fn (SupportTicket $record): string => $record->statusLabel())
                    ->color(fn (SupportTicket $record): string => match ($record->status) {
                        'new' => 'warning',
                        'in_progress' => 'info',
                        default => 'gray',
                    }),
                TextColumn::make('created_at')
                    ->label('تاريخ الإرسال')
                    ->dateTime('Y-m-d H:i')
                    ->sortable(),
            ])
            ->defaultSort('id', 'desc')
            ->filters([
                SelectFilter::make('status')
                    ->label('الحالة')
                    ->options(SupportTicket::STATUSES),
            ])
            ->recordActions([
                ViewAction::make(),
                Action::make('markProgress')
                    ->label('متابعة')
                    ->icon(Heroicon::OutlinedArrowPath)
                    ->visible(fn (SupportTicket $record): bool => $record->status === 'new')
                    ->action(fn (SupportTicket $record) => $record->update([
                        'status' => 'in_progress',
                        'read_at' => $record->read_at ?? now(),
                    ])),
                Action::make('close')
                    ->label('إغلاق')
                    ->icon(Heroicon::OutlinedCheckCircle)
                    ->color('success')
                    ->visible(fn (SupportTicket $record): bool => $record->status !== 'closed')
                    ->action(fn (SupportTicket $record) => $record->update(['status' => 'closed'])),
            ]);
    }

    public static function getEloquentQuery(): Builder
    {
        return parent::getEloquentQuery()->with('user');
    }

    public static function getPages(): array
    {
        return [
            'index' => ListSupportTickets::route('/'),
            'view' => ViewSupportTicket::route('/{record}'),
        ];
    }
}
