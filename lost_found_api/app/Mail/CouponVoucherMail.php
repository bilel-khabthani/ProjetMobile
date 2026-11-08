<?php

namespace App\Mail;

use App\Models\UserCoupon;
use App\Services\PdfService;
use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Attachment;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

class CouponVoucherMail extends Mailable
{
    use Queueable, SerializesModels;

    public function __construct(
        public UserCoupon $coupon
    ) {}

    public function envelope(): Envelope
    {
        return new Envelope(
            subject: '🎁 Votre bon de réduction '.$this->coupon->partner_name.' — Lost&Found AI',
        );
    }

    public function content(): Content
    {
        return new Content(
            view: 'emails.coupon',
            with: [
                'coupon' => $this->coupon->loadMissing('user', 'reward'),
            ],
        );
    }

    public function attachments(): array
    {
        $pdfService = app(PdfService::class);
        $pdfContent = $pdfService->generateCouponPdf($this->coupon);

        return [
            Attachment::fromData(fn () => $pdfContent, 'Bon-Reduction-'.$this->coupon->code.'.pdf')
                ->withMime('application/pdf'),
        ];
    }
}

