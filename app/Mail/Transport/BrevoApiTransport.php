<?php

namespace App\Mail\Transport;

use Illuminate\Support\Facades\Http;
use Symfony\Component\Mailer\Exception\TransportException;
use Symfony\Component\Mailer\SentMessage;
use Symfony\Component\Mailer\Transport\AbstractTransport;
use Symfony\Component\Mime\Address;
use Symfony\Component\Mime\MessageConverter;

class BrevoApiTransport extends AbstractTransport
{
    public const ENDPOINT = 'https://api.brevo.com/v3';

    public function __construct(private readonly string $key)
    {
        parent::__construct();
    }

    protected function doSend(SentMessage $message): void
    {
        $email = MessageConverter::toEmail($message->getOriginalMessage());
        $envelope = $message->getEnvelope();
        $from = $envelope->getSender();

        $map = fn (array $addresses): array => array_map(
            fn (Address $address): array => array_filter([
                'email' => $address->getAddress(),
                'name' => $address->getName() ?: null,
            ]),
            $addresses,
        );

        $payload = array_filter([
            'sender' => array_filter(['email' => $from->getAddress(), 'name' => $from->getName() ?: null]),
            'to' => $map($email->getTo() ?: $envelope->getRecipients()),
            'cc' => $map($email->getCc()) ?: null,
            'bcc' => $map($email->getBcc()) ?: null,
            'replyTo' => ($reply = $email->getReplyTo()[0] ?? null)
                ? array_filter(['email' => $reply->getAddress(), 'name' => $reply->getName() ?: null])
                : null,
            'subject' => $email->getSubject() ?: '(بدون عنوان)',
            'htmlContent' => $email->getHtmlBody() ?: null,
            'textContent' => $email->getTextBody() ?: null,
            'attachment' => array_values(array_map(fn ($part): array => [
                'name' => $part->getFilename() ?: 'attachment',
                'content' => base64_encode($part->getBody()),
            ], $email->getAttachments())) ?: null,
        ], fn ($value) => $value !== null);

        if (! isset($payload['htmlContent']) && ! isset($payload['textContent'])) {
            $payload['textContent'] = ' ';
        }

        $response = Http::withHeaders(['api-key' => $this->key])
            ->acceptJson()
            ->timeout(15)
            ->post(self::ENDPOINT.'/smtp/email', $payload);

        if ($response->failed()) {
            throw new TransportException('Brevo: '.($response->json('message') ?: $response->body()), $response->status());
        }

        if ($id = $response->json('messageId')) {
            $message->setMessageId(trim((string) $id, '<>'));
        }
    }

    public function __toString(): string
    {
        return 'brevo+api://default';
    }
}
