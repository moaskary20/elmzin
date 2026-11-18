<?php

namespace App\Filament\Resources\SupportTickets\Pages;

use App\Filament\Resources\SupportTicketResource;
use Filament\Resources\Pages\ViewRecord;

class ViewSupportTicket extends ViewRecord
{
    protected static string $resource = SupportTicketResource::class;

    public function mount(int|string $record): void
    {
        parent::mount($record);

        if ($this->record->status === 'new') {
            $this->record->update([
                'status' => 'in_progress',
                'read_at' => $this->record->read_at ?? now(),
            ]);
        }
    }
}
