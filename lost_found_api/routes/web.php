<?php

use App\Mail\CouponVoucherMail;
use App\Models\UserCoupon;
use App\Services\PdfService;
use Illuminate\Support\Facades\Mail;
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
    if (! $coupon) {
        return 'Aucun coupon trouvé dans la base de données.';
    }

    return view('emails.coupon', ['coupon' => $coupon]);
});

/**
 * Route de déclenchement direct d'un envoi de test avec le bon PDF joint.
 */
Route::get('/send-test-email', function () {
    $coupon = UserCoupon::with('user', 'reward')->latest()->first();
    if (! $coupon) {
        return 'Aucun coupon trouvé dans la base de données.';
    }

    $dest = config('mail.demo_redirect') ?: config('mail.from.address');

    try {
        Mail::to($dest)->send(new CouponVoucherMail($coupon));

        return '<div style="font-family:sans-serif;padding:30px;text-align:center;">'
            .'<h2 style="color:#16a34a;">✅ E-mail de test envoyé à '.e($dest).' !</h2>'
            .'<p style="color:#475569;font-size:16px;">Le bon de réduction avec son <strong>PDF officiel en pièce jointe</strong> a été transmis au serveur SMTP configuré.</p>'
            .'<p style="color:#64748b;font-size:14px;">En développement, ouvrez Mailpit sur <a href="http://127.0.0.1:8025">http://127.0.0.1:8025</a> pour consulter les e-mails.</p>'
            .'<br><a href="/mail-preview" style="background:#2563eb;color:white;padding:10px 20px;text-decoration:none;border-radius:8px;">Voir l\'aperçu</a>'
            .'</div>';
    } catch (Throwable $e) {
        return '<div style="font-family:sans-serif;padding:30px;color:#dc2626;">'
            .'<h2>❌ Erreur d\'envoi SMTP :</h2>'
            .'<pre>'.htmlspecialchars($e->getMessage()).'</pre>'
            .'</div>';
    }
});
