# Lost&Found AI

Application de gestion d'objets perdus/trouvés : API Laravel (`lost_found_api`) +
application Flutter (`lost_found_ai`). Ce guide permet à un nouveau développeur de
lancer le projet, d'envoyer de vrais e-mails et de se connecter avec Google.

> Aucun secret n'est versionné. `lost_found_api/.env`, la base SQLite et les
> fichiers générés (`vendor`, `build`, `.dart_tool`, PDF de coupons…) sont
> ignorés par Git. Chaque développeur crée donc son propre `.env`.

## Prérequis

- PHP **8.3 ou plus** (le projet est verrouillé pour fonctionner dès PHP 8.3)
- [Composer](https://getcomposer.org/)
- Flutter **3.47+** / Dart 3.13+
- PostgreSQL (ou SQLite pour un démarrage rapide)
- Facultatif : Docker pour Mailpit (capture locale des e-mails)

## 1. API Laravel

```powershell
cd lost_found_api
copy .env.example .env
composer install
php artisan key:generate
```

### Base de données

Le `.env.example` pointe vers PostgreSQL :

```env
DB_CONNECTION=pgsql
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=lost_found
DB_USERNAME=lostfound
DB_PASSWORD=lostfound2026
```

Pour un démarrage sans PostgreSQL, utiliser SQLite :

```env
DB_CONNECTION=sqlite
# DB_DATABASE peut rester vide : database/database.sqlite sera utilisé
```

Puis :

```powershell
php artisan migrate --seed
php artisan storage:link
php artisan serve
```

L'API répond sur `http://127.0.0.1:8000/api`. Un seul backend peut écouter sur
le port 8000 à la fois : arrêter l'instance précédente avant d'en démarrer une
autre.

### E-mails (coupons, OTP, réinitialisation)

Deux options, à régler dans `lost_found_api/.env` :

**A. Mailpit (recommandé en développement) — aucun compte requis**

```powershell
docker compose up -d mailpit
```

```env
MAIL_MAILER=smtp
MAIL_HOST=127.0.0.1
MAIL_PORT=1025
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_FROM_ADDRESS="no-reply@lostfound.local"
```

Les e-mails sont visibles sur <http://localhost:8025>, rien ne part vers
l'extérieur.

**B. Gmail SMTP (envoi réel)**

1. Activer la validation en deux étapes sur le compte Gmail.
2. Créer un **mot de passe d'application** (Google Account → Sécurité → Mots de
   passe d'application), pas le mot de passe du compte.
3. Renseigner le `.env` :

```env
MAIL_MAILER=smtp
MAIL_SCHEME=tls
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_USERNAME=votre-adresse@gmail.com
MAIL_PASSWORD=mot-de-passe-application-16-caracteres
MAIL_FROM_ADDRESS="votre-adresse@gmail.com"
```

Le mot de passe d'application reste uniquement dans `.env` (ignoré par Git).
`MAIL_DEMO_REDIRECT` permet de rediriger tous les envois vers une boîte de test.

Après modification du `.env` :

```powershell
php artisan config:clear
```

## 2. Application Flutter

```powershell
cd lost_found_ai
flutter pub get
flutter run
```

L'URL de l'API est choisie automatiquement (`lib/core/app_config.dart`) :

| Cible            | URL par défaut              |
| ---------------- | --------------------------- |
| Émulateur Android | `http://10.0.2.2:8000/api` |
| Web / navigateur  | `http://127.0.0.1:8000/api` |

Surcharge possible au lancement (appareil physique, autre port…) :

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000/api
```

### Connexion Google (vraie authentification)

La connexion utilise `google_sign_in`. Aucun compte de démonstration n'est
fabriqué : l'utilisateur choisit un vrai compte Google.

- Client **Web** OAuth (utilisé comme `serverClientId` Android / `clientId` Web) :
  défini dans `lib/core/app_config.dart` et surchargeable :

  ```powershell
  flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>
  ```

- Pour Android, un client OAuth **Android** doit exister dans Google Cloud
  Console pour le package `fr.campus.lost_found_ai` **et** l'empreinte SHA-1 du
  certificat utilisé pour signer l'APK. Chaque poste de développement a souvent
  une empreinte différente : sans enregistrement, `signIn()` échoue avec
  `DEVELOPER_ERROR (10)`.

  Récupérer l'empreinte de debug :

  ```powershell
  cd lost_found_ai/android
  .\gradlew signingReport
  ```

  ou :

  ```powershell
  keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" `
    -alias androiddebugkey -storepass android -keypass android
  ```

  Ajouter ensuite ce SHA-1 au client OAuth Android dans Google Cloud Console.

- Sur le Web, ajouter l'origine du site (ex. `http://localhost:8080`) aux
  origines autorisées du client OAuth Web.
- Si l'application OAuth est en mode « Testing », ajouter les comptes Google des
  testeurs dans Google Cloud Console.

## 3. Vérifications

```powershell
# Backend
cd lost_found_api
php artisan test

# Frontend
cd ..\lost_found_ai
flutter analyze
flutter test
```

## Structure

```
lost_found_api/   API Laravel (auth, objets, matching, chat modéré, rewards)
lost_found_ai/    Application Flutter (Riverpod, GoRouter)
```
