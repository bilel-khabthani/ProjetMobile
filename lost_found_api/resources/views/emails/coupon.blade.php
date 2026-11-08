<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <title>Votre Bon de Réduction Lost&Found</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background-color: #f1f5f9;
            color: #334155;
            margin: 0;
            padding: 20px;
        }
        .card {
            max-width: 600px;
            margin: 0 auto;
            background: #ffffff;
            border-radius: 12px;
            overflow: hidden;
            box-shadow: 0 4px 15px rgba(0, 0, 0, 0.05);
            border: 1px solid #e2e8f0;
        }
        .header {
            background: #0f172a;
            color: #ffffff;
            padding: 24px;
            text-align: center;
        }
        .header h1 {
            margin: 0;
            font-size: 22px;
        }
        .body {
            padding: 24px;
        }
        .coupon-banner {
            background: #eff6ff;
            border: 2px dashed #3b82f6;
            border-radius: 8px;
            padding: 20px;
            text-align: center;
            margin: 20px 0;
        }
        .promo-code {
            font-family: monospace;
            font-size: 28px;
            font-weight: bold;
            color: #1d4ed8;
            letter-spacing: 3px;
            margin: 10px 0;
        }
        .footer {
            background: #f8fafc;
            padding: 16px;
            text-align: center;
            font-size: 12px;
            color: #94a3b8;
        }
    </style>
</head>
<body>
    @if(request()->is('mail-preview*') || request()->is('/'))
    <div style="max-width: 600px; margin: 0 auto 15px; padding: 14px 18px; background: #e0f2fe; border: 1px solid #7dd3fc; border-radius: 8px; font-family: sans-serif; box-shadow: 0 2px 8px rgba(0,0,0,0.05);">
        <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 10px;">
            <div>
                <strong style="color: #0369a1; font-size: 15px;">📧 Service E-mail & Bon PDF Actif</strong><br>
                <span style="color: #0284c7; font-size: 13px;">Compte : <strong>jomaafares9@gmail.com</strong> (SMTP Gmail connecté)</span>
            </div>
            <div style="display: flex; gap: 8px;">
                <a href="/send-test-email" style="background: #16a34a; color: white; padding: 9px 14px; text-decoration: none; border-radius: 6px; font-weight: bold; font-size: 13px; display: inline-block;">
                    ✉️ Envoyer à mon Gmail
                </a>
                <a href="/coupons/{{ $coupon->code }}/pdf" target="_blank" style="background: #0284c7; color: white; padding: 9px 14px; text-decoration: none; border-radius: 6px; font-weight: bold; font-size: 13px; display: inline-block;">
                    📄 Télécharger PDF
                </a>
            </div>
        </div>
    </div>
    @endif
    <div class="card">
        <div class="header">
            <h1>🎁 Félicitations {{ $coupon->user->name ?? 'Cher Membre' }} !</h1>
            <p style="margin: 6px 0 0; color: #94a3b8; font-size: 13px;">Votre récompense Lost&Found AI est disponible</p>
        </div>
        <div class="body">
            <p>Bonjour {{ $coupon->user->name ?? '' }},</p>
            <p>
                Merci pour votre engagement civique au sein de notre communauté !
                Voici votre bon de réduction exclusif chez notre partenaire <strong>{{ $coupon->partner_name }}</strong> :
            </p>

            <div class="coupon-banner">
                <div style="font-size: 13px; color: #64748b; text-transform: uppercase; font-weight: bold;">
                    {{ $coupon->title }}
                </div>
                <div style="font-size: 20px; font-weight: bold; color: #0f172a; margin: 6px 0;">
                    {{ $coupon->discount_text }}
                </div>
                <div class="promo-code">{{ $coupon->code }}</div>
                <div style="font-size: 12px; color: #64748b;">
                    Valable jusqu'au <strong>{{ $coupon->expires_at->format('d/m/Y') }}</strong>
                </div>
            </div>

            <p style="font-size: 13px; color: #475569;">
                📎 <strong>Bon au format PDF joint :</strong> Vous trouverez ci-joint votre bon officiel au format PDF à présenter ou conserver lors de vos commandes.
            </p>

            <p style="font-size: 13px; color: #64748b; margin-top: 25px;">
                À très bientôt sur Lost&Found AI,<br>
                <em>L'équipe du projet Campus</em>
            </p>
        </div>
        <div class="footer">
            Lost&Found AI — Plateforme de Restitution Citoyenne
        </div>
    </div>
</body>
</html>

