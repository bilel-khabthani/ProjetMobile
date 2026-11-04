<?php

require __DIR__.'/vendor/autoload.php';

$app = require_once __DIR__.'/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

$coupon = App\Models\UserCoupon::with('user', 'reward')->first();

if (!$coupon) {
    echo "Aucun coupon trouvé.\n";
    exit(1);
}

echo "Génération du PDF pour le coupon : " . $coupon->code . " (" . $coupon->partner_name . ")\n";

$pdfService = app(App\Services\PdfService::class);
$pdfContent = $pdfService->generateCouponPdf($coupon);

$outputDir = __DIR__ . '/public/vouchers';
if (!file_exists($outputDir)) {
    mkdir($outputDir, 0755, true);
}

$pdfPath = $outputDir . '/Bon-Reduction-' . $coupon->code . '.pdf';
file_put_contents($pdfPath, $pdfContent);

// Copier aussi à la racine du projet pour accès immédiat de l'utilisateur
file_put_contents(dirname(__DIR__) . '/Bon-Reduction-' . $coupon->code . '.pdf', $pdfContent);

echo "PDF généré avec succès ! (" . strlen($pdfContent) . " octets)\n";
echo "Chemin 1: " . $pdfPath . "\n";
echo "Chemin 2: " . dirname(__DIR__) . '/Bon-Reduction-' . $coupon->code . '.pdf' . "\n";

