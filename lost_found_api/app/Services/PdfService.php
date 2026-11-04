<?php

namespace App\Services;

use App\Models\UserCoupon;
use Dompdf\Dompdf;
use Dompdf\Options;
use Illuminate\Support\Facades\View;

class PdfService
{
    /**
     * Génère le flux binaire PDF du coupon de réduction.
     */
    public function generateCouponPdf(UserCoupon $coupon): string
    {
        $options = new Options();
        $options->set('isHtml5ParserEnabled', true);
        $options->set('isRemoteEnabled', true);
        $options->set('defaultFont', 'Helvetica');

        $dompdf = new Dompdf($options);
        $html = View::make('pdf.coupon', ['coupon' => $coupon->loadMissing('user', 'reward')])->render();

        $dompdf->loadHtml($html);
        $dompdf->setPaper('A4', 'portrait');
        $dompdf->render();

        return $dompdf->output();
    }
}

