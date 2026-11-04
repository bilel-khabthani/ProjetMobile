<?php

use App\Models\UserCoupon;
use App\Services\PdfService;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return redirect('/mail-preview');
});

/**
 * Aperçu et téléchargement direct du PDF officiel dans le navigateur.
 */
Route::get('/coupons/{coupon:code}/pdf', function (UserCoupon $coupon, PdfService $pdfService) {
    $pdf = $pdfService->generateCouponPdf($coupon);
    return response($pdf, 200, [
        'Content-Type' => 'application/pdf',
        'Content-Disposition' => 'inline; filename="Bon-Reduction-'.$coupon->code.'.pdf"',
    ]);
});

/**
 * Aperçu HTML du bon pour vérification rapide sans lecteur PDF.
 */
Route::get('/coupons/{coupon:code}/view', function (UserCoupon $coupon) {
    return view('pdf.coupon', ['coupon' => $coupon->loadMissing('user', 'reward')]);
});

/**
 * Visualiseur d'e-mails envoyés pour tester et valider sans configuration SMTP externe.
 */
Route::get('/mail-preview', function () {
    $coupon = UserCoupon::with('user', 'reward')->latest()->first();
    if (!$coupon) {
        return 'Aucun coupon trouvé dans la base de données.';
    }
    return view('emails.coupon', ['coupon' => $coupon]);
});

/**
 * Route de déclenchement direct d'envoi à votre adresse Gmail avec le bon PDF joint.
 */
Route::get('/send-test-email', function () {
    $coupon = UserCoupon::with('user', 'reward')->latest()->first();
    if (!$coupon) {
        return 'Aucun coupon trouvé dans la base de données.';
    }
    try {
        \Illuminate\Support\Facades\Mail::to('jomaafares9@gmail.com')->send(new \App\Mail\CouponVoucherMail($coupon));
        return '<div style="font-family:sans-serif;padding:30px;text-align:center;">'
            . '<h2 style="color:#16a34a;">✅ E-mail envoyé avec succès à jomaafares9@gmail.com !</h2>'
            . '<p style="color:#475569;font-size:16px;">Le bon de réduction avec son <strong>PDF officiel en pièce jointe</strong> a été transmis via smtp.gmail.com.</p>'
            . '<p style="color:#64748b;font-size:14px;">Vérifiez votre boîte de réception Gmail (ou le dossier Promotions / Spams).</p>'
            . '<br><a href="/mail-preview" style="background:#2563eb;color:white;padding:10px 20px;text-decoration:none;border-radius:8px;">Voir l\'aperçu</a>'
            . '</div>';
    } catch (\Throwable $e) {
        return '<div style="font-family:sans-serif;padding:30px;color:#dc2626;">'
            . '<h2>❌ Erreur d\'envoi SMTP :</h2>'
            . '<pre>' . htmlspecialchars($e->getMessage()) . '</pre>'
            . '</div>';
    }
});

