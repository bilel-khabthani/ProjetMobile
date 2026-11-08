<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <title>Bon de Réduction - {{ $coupon->title }}</title>
    <style>
        @page {
            margin: 20px;
            size: A4 portrait;
        }
        body {
            font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;
            color: #1e293b;
            background-color: #f8fafc;
            margin: 0;
            padding: 20px;
        }
        .container {
            max-width: 680px;
            margin: 0 auto;
            background: #ffffff;
            border-radius: 16px;
            overflow: hidden;
            box-shadow: 0 4px 20px rgba(0, 0, 0, 0.08);
            border: 1px solid #e2e8f0;
        }
        .header {
            background: linear-gradient(135deg, #1e293b 0%, #0f172a 100%);
            color: #ffffff;
            padding: 30px;
            text-align: center;
            position: relative;
        }
        .header h1 {
            margin: 0 0 6px 0;
            font-size: 24px;
            letter-spacing: 1px;
            text-transform: uppercase;
        }
        .header .subtitle {
            font-size: 13px;
            color: #94a3b8;
            margin: 0;
        }
        .partner-badge {
            display: inline-block;
            background: #f59e0b;
            color: #ffffff;
            font-weight: bold;
            font-size: 12px;
            padding: 6px 14px;
            border-radius: 20px;
            margin-top: 15px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        .content {
            padding: 30px;
        }
        .ticket {
            border: 2px dashed #cbd5e1;
            background: #fffbeb;
            border-radius: 12px;
            padding: 24px;
            text-align: center;
            margin: 20px 0;
            position: relative;
        }
        .ticket-title {
            font-size: 15px;
            font-weight: 600;
            color: #78350f;
            text-transform: uppercase;
            letter-spacing: 1px;
            margin-bottom: 8px;
        }
        .discount {
            font-size: 32px;
            font-weight: 800;
            color: #b45309;
            margin: 10px 0;
        }
        .coupon-code-box {
            display: inline-block;
            background: #ffffff;
            border: 2px solid #f59e0b;
            border-radius: 8px;
            padding: 12px 24px;
            margin: 15px 0 5px 0;
        }
        .coupon-code {
            font-family: 'Courier New', Courier, monospace;
            font-size: 26px;
            font-weight: bold;
            letter-spacing: 4px;
            color: #1e293b;
        }
        .instructions {
            font-size: 11px;
            color: #64748b;
            margin-top: 8px;
        }
        .details-grid {
            width: 100%;
            margin: 20px 0;
            border-collapse: collapse;
        }
        .details-grid td {
            padding: 10px 12px;
            border-bottom: 1px solid #f1f5f9;
            font-size: 13px;
        }
        .details-grid .label {
            color: #64748b;
            font-weight: 600;
            width: 40%;
        }
        .details-grid .value {
            color: #0f172a;
            font-weight: bold;
        }
        .qr-placeholder {
            text-align: center;
            padding: 15px;
            background: #f8fafc;
            border-radius: 8px;
            margin: 20px 0;
        }
        .barcode {
            font-family: 'Courier New', monospace;
            font-size: 20px;
            letter-spacing: 6px;
            color: #334155;
            margin: 10px 0;
            font-weight: bold;
        }
        .how-to {
            background: #f0fdf4;
            border: 1px solid #bbf7d0;
            border-radius: 10px;
            padding: 16px;
            margin-top: 20px;
        }
        .how-to h4 {
            margin: 0 0 10px 0;
            color: #166534;
            font-size: 14px;
        }
        .how-to ol {
            margin: 0;
            padding-left: 20px;
            color: #15803d;
            font-size: 12px;
            line-height: 1.6;
        }
        .footer {
            background: #f8fafc;
            border-top: 1px solid #e2e8f0;
            padding: 18px 30px;
            font-size: 11px;
            color: #94a3b8;
            text-align: center;
        }
        .stamp {
            display: inline-block;
            border: 2px solid #059669;
            color: #059669;
            padding: 4px 10px;
            border-radius: 6px;
            font-weight: bold;
            font-size: 10px;
            text-transform: uppercase;
            letter-spacing: 1px;
            margin-top: 5px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Lost & Found AI</h1>
            <p class="subtitle">Programme de Récompense & Citoyenneté Campus</p>
            <div class="partner-badge">Partenariat Officiel : {{ $coupon->partner_name }}</div>
        </div>

        <div class="content">
            <div class="ticket">
                <div class="ticket-title">★ Bon de Réduction Exclusif ★</div>
                <div class="discount">{{ $coupon->discount_text }}</div>
                
                <div class="coupon-code-box">
                    <span class="coupon-code">{{ $coupon->code }}</span>
                </div>
                <div class="instructions">À renseigner dans l'application partenaire ou à présenter lors de votre commande</div>
            </div>

            <table class="details-grid">
                <tr>
                    <td class="label">Bénéficiaire</td>
                    <td class="value">{{ $coupon->user->name ?? 'Étudiant Campus' }}</td>
                </tr>
                <tr>
                    <td class="label">Adresse e-mail</td>
                    <td class="value">{{ $coupon->user->email ?? 'Non renseignée' }}</td>
                </tr>
                <tr>
                    <td class="label">Partenaire</td>
                    <td class="value">{{ $coupon->partner_name }} ({{ $coupon->partner_type }})</td>
                </tr>
                <tr>
                    <td class="label">Date d'émission</td>
                    <td class="value">{{ $coupon->created_at->format('d/m/Y à H:i') }}</td>
                </tr>
                <tr>
                    <td class="label">Date d'expiration</td>
                    <td class="value" style="color: #dc2626;">{{ $coupon->expires_at->format('d/m/Y à 23:59') }}</td>
                </tr>
                <tr>
                    <td class="label">Origine de la récompense</td>
                    <td class="value">{{ $coupon->source === 'RESTITUTION' ? 'Restitution d\'un objet trouvé (Civisme)' : ($coupon->source === 'WHEEL_SPIN' ? 'Gain à la Roue de la Fortune' : 'Échange de points fidélité') }}</td>
                </tr>
                <tr>
                    <td class="label">Conditions d'application</td>
                    <td class="value" style="font-weight: normal; font-size: 12px; color: #475569;">{{ $coupon->terms ?? 'Valable une seule fois chez le partenaire sur présentation de ce bon ou saisie du code promo.' }}</td>
                </tr>
            </table>

            <div class="qr-placeholder">
                <div style="font-size: 12px; color: #64748b; font-weight: 600;">CODE DE VALIDATION LIVREUR / GUICHET</div>
                <div class="barcode">||| | |||| | ||| |||| | ||| | ||</div>
                <div style="font-size: 11px; color: #94a3b8;">N° Série Sécurisé : {{ strtoupper(substr($coupon->id, 0, 18)) }}</div>
            </div>

            <div class="how-to">
                <h4>Comment utiliser votre bon de réduction ?</h4>
                <ol>
                    <li>Ouvrez l'application mobile <strong>{{ $coupon->partner_name }}</strong> (ou rendez-vous au point partenaire).</li>
                    <li>Composez votre panier de livraison ou commande repas.</li>
                    <li>Dans la section <em>« Code promo / Bon d'achat »</em>, entrez le code : <strong>{{ $coupon->code }}</strong>.</li>
                    <li>La remise <strong>{{ $coupon->discount_text }}</strong> sera déduite immédiatement du montant total.</li>
                </ol>
            </div>
        </div>

        <div class="footer">
            <div>Document certifié généré par l'API Lost&Found AI — Plateforme Intelligente d'Objets Trouvés</div>
            <div class="stamp">✓ Certificat Officiel Vérifié</div>
        </div>
    </div>
</body>
</html>

