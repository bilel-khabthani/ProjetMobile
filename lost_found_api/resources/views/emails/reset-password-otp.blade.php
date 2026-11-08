<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Réinitialisation de votre mot de passe</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
            background-color: #F8FAFC;
            color: #1E293B;
            margin: 0;
            padding: 0;
            -webkit-text-size-adjust: none;
        }
        .container {
            max-width: 560px;
            margin: 40px auto;
            background: #FFFFFF;
            border-radius: 16px;
            overflow: hidden;
            border: 1px solid #E2E8F0;
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05);
        }
        .header {
            background: linear-gradient(135deg, #0284C7 0%, #0369A1 100%);
            padding: 32px 24px;
            text-align: center;
            color: #FFFFFF;
        }
        .header h1 {
            margin: 0;
            font-size: 24px;
            font-weight: 800;
            letter-spacing: -0.5px;
        }
        .header p {
            margin: 8px 0 0;
            font-size: 14px;
            opacity: 0.9;
        }
        .body {
            padding: 32px 28px;
        }
        .greeting {
            font-size: 16px;
            font-weight: 600;
            margin-bottom: 12px;
        }
        .message {
            font-size: 15px;
            line-height: 1.6;
            color: #475569;
            margin-bottom: 24px;
        }
        .otp-box {
            background-color: #F0F9FF;
            border: 2px dashed #0284C7;
            border-radius: 12px;
            padding: 20px;
            text-align: center;
            margin: 28px 0;
        }
        .otp-code {
            font-size: 36px;
            font-weight: 800;
            letter-spacing: 12px;
            color: #0369A1;
            font-family: monospace, Courier;
            display: inline-block;
            margin-left: 12px;
        }
        .expiry-notice {
            font-size: 13px;
            color: #64748B;
            margin-top: 8px;
        }
        .warning-box {
            background-color: #FFFBEB;
            border-left: 4px solid #F59E0B;
            padding: 12px 16px;
            border-radius: 6px;
            font-size: 13px;
            color: #92400E;
            margin-top: 24px;
            line-height: 1.5;
        }
        .footer {
            background-color: #F8FAFC;
            border-top: 1px solid #E2E8F0;
            padding: 20px 24px;
            text-align: center;
            font-size: 12px;
            color: #94A3B8;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Lost&Found AI</h1>
            <p>Smart Object Recovery</p>
        </div>
        <div class="body">
            <div class="greeting">
                Bonjour{{ $user?->name ? ' ' . $user->name : '' }},
            </div>
            <div class="message">
                Vous avez demandé la réinitialisation du mot de passe de votre compte Lost&Found AI. Voici votre code de vérification à usage unique (OTP) :
            </div>
            <div class="otp-box">
                <div class="otp-code">{{ $code }}</div>
                <div class="expiry-notice">Ce code est valide pendant <strong>15 minutes</strong>.</div>
            </div>
            <div class="warning-box">
                <strong>Sécurité :</strong> Ne partagez jamais ce code avec quiconque. Si vous n'êtes pas à l'origine de cette demande, vous pouvez ignorer cet e-mail en toute sécurité : votre compte reste protégé.
            </div>
        </div>
        <div class="footer">
            &copy; {{ date('Y') }} Lost&Found AI. Tous droits réservés.
        </div>
    </div>
</body>
</html>
