# Lost&Found AI

Application mobile de mise en relation entre objets perdus et objets trouvés.

Le dépôt contient deux projets :

- `lost_found_api/` : API Laravel 13 (authentification, objets, matching, chat, modération, confiance, récompenses).
- `lost_found_ai/` : application Flutter (Riverpod, GoRouter, WebSocket, cartes, caméra/galerie).

> Aucun secret n'est versionné. `.env`, la base SQLite, `vendor/`, `build/`, `.dart_tool/` et les fichiers générés sont ignorés par Git. Chaque développeur crée son propre `.env`.

---

## 1. Prérequis

### Commun

- Git
- Un éditeur (VS Code, Android Studio, etc.)

### API Laravel

- PHP **8.3+**
- Composer
- SQLite (démarrage rapide) ou PostgreSQL
- Docker uniquement si vous voulez Mailpit pour capturer les e-mails localement

### Application Flutter

- Flutter récent avec Dart **>= 3.12**
- Android SDK pour émulateur / APK
- Un appareil Android physique ou un émulateur

---

## 2. Démarrage rapide

Le dépôt contient `setup.ps1` et `setup.cmd` pour préparer l'environnement local. Vous pouvez aussi suivre les étapes manuelles ci-dessous.

### API Laravel

```powershell
cd lost_found_api
copy .env.example .env
composer install
php artisan key:generate
```

Pour utiliser SQLite rapidement :

```env
DB_CONNECTION=sqlite
DB_DATABASE=database/database.sqlite
```

Puis :

```powershell
php artisan migrate --seed
php artisan storage:link
php artisan serve --host=0.0.0.0 --port=8000
```

L'API répond sur :

```text
http://127.0.0.1:8000/api
```

Vérification rapide :

```powershell
curl http://127.0.0.1:8000/api/ping
```

Réponse attendue :

```json
{"status":"ok","app":"Lost&Found AI"}
```

> Un seul serveur peut écouter sur le port `8000`. Arrêtez l'instance précédente avant d'en lancer une autre.

### Application Flutter

```powershell
cd lost_found_ai
flutter pub get
flutter run
```

---

## 3. Configuration de l'URL de l'API

L'URL est choisie dans `lost_found_ai/lib/core/app_config.dart` et `lib/data/api_client.dart`.

| Cible | URL par défaut |
| --- | --- |
| Émulateur Android | `http://10.0.2.2:8000/api` |
| Web / navigateur | `http://127.0.0.1:8000/api` |
| Appareil physique | à fournir avec `--dart-define` |

Exemple :

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000/api
```

Pour un APK :

```powershell
flutter build apk --release --split-per-abi --target-platform android-arm64 `
  --dart-define=API_BASE_URL=http://192.168.1.20:8000/api
```

Android bloque le HTTP en clair par défaut. Si vous ciblez une IP LAN ou une IP Tailscale, ajoutez-la dans :

```text
lost_found_ai/android/app/src/main/res/xml/network_security_config.xml
```

Exemple :

```xml
<domain includeSubdomains="false">192.168.1.20</domain>
```

### Cas des hotspots téléphone

Si le PC et le téléphone de test sont tous les deux clients d'un hotspot qui active l'isolation client/client, le téléphone ne pourra pas joindre le PC via son IP LAN (`192.168.x.x`, `172.20.x.x`, etc.), même si le ping fonctionne depuis le PC.

Options possibles :

1. Connecter les deux appareils à un vrai routeur Wi-Fi sans isolation client/client.
2. Utiliser `adb reverse tcp:8000 tcp:8000` et cibler `http://127.0.0.1:8000/api` depuis le téléphone.
3. Utiliser Tailscale sur les deux appareils et cibler l'IP Tailscale du PC.
4. Exposer temporairement l'API derrière un tunnel HTTPS.

---

## 4. Architecture

```text
Flutter (lost_found_ai)
  ├── lib/core/          configuration, thème, animation, IA locale
  ├── lib/data/          ApiClient, repositories, providers Riverpod, modèles
  ├── lib/features/      écrans par domaine (auth, home, objets, swipe, chat...)
  └── lib/widgets/       composants réutilisables

Laravel (lost_found_api)
  ├── routes/api.php     routes /api
  ├── app/Http/Controllers/Api/
  ├── app/Services/      matching, texte, image, confiance, modération, IA
  ├── app/Models/        User, Item, ItemMatch, Message, Claim, Reward...
  ├── database/migrations/
  └── tests/             tests Feature et Unit
```

### Authentification

- Laravel Sanctum, jetons stockés côté Flutter avec `flutter_secure_storage`.
- Google Sign-In natif via `google_sign_in`.
- OTP téléphone en démonstration, vérification requise pour les services sensibles.
- Middleware : `auth:sanctum` puis `verified-phone` pour objets, matching, swipe, chat et rewards.

### Principales routes API

| Domaine | Routes |
| --- | --- |
| Ping | `GET /api/ping` |
| Auth | `/api/auth/register`, `/login`, `/google`, `/otp/request`, `/otp/verify`, `/logout`, `/me` |
| Objets | `GET/POST /api/items`, `/api/objects`, `/api/items/{item}`, `/api/objects/{item}`, `/mine`, `/nearby` |
| Matching | `/api/items/{item}/matches`, `/api/objects/{item}/matches` |
| Swipe | `GET /api/swipe/deck`, `POST /api/swipe/{match}/decision`, `GET /api/swipe/{match}/insight` |
| Chat | `/api/matches`, `/api/matches/{match}`, `/messages`, `/messages/read`, `/messages/{message}/report` |
| Trust | `GET /api/trust/me`, `POST /api/trust/events/{event}/appeal` |
| Claims | `GET/POST /api/claims`, `/respond`, `/resolve`, `/escalate` |
| Rewards | `/api/rewards`, `/wallet`, `/redeem`, `/wheel/spin`, `/my-coupons` |

---

## 5. Modules métier

### 5.1 Cartes Tinder / Swipe

Fichiers principaux :

```text
lost_found_ai/lib/features/swipe/swipe_screen.dart
lost_found_ai/lib/features/swipe/widgets/ai_insight_sheet.dart
lost_found_api/app/Http/Controllers/Api/SwipeController.php
lost_found_api/app/Services/Ai/SwipeAiService.php
lost_found_api/app/Services/MatchingService.php
```

Fonctionnement :

1. L'écran swipe demande `GET /api/swipe/deck`.
2. Le backend relance le matching pour les annonces `LOST` actives de l'utilisateur.
3. Les décisions déjà prises sont exclues via la table `swipe_decisions`.
4. Chaque carte affiche un objet `FOUND` candidat, un aperçu d'insight et les actions `LIKE` / `PASS`.
5. `POST /api/swipe/{match}/decision` enregistre la décision dans `swipe_decisions` et met à jour `matches.decision.answer` (`YES` pour `LIKE`, `NO` pour `PASS`).
6. `GET /api/swipe/{match}/insight` fournit une explication détaillée, avec cache par `match_id` et `updated_at`.

Score de matching :

- image, localisation, temps et texte ;
- distance avec décroissance linéaire jusqu'à 50 km ;
- fenêtre temporelle de 12 h à 14 jours ;
- `YES >= 80`, `UNSURE >= 60`, sinon `NO` ;
- exclusion stricte de l'auto-match et des objets de même type.

L'insight peut utiliser OpenAI si `OPENAI_API_KEY` est configuré. Sans clé, le backend utilise un heuristique déterministe local. Le secret d'un objet perdu n'est jamais envoyé à OpenAI.

### 5.2 Messagerie et corrélation

Fichiers principaux :

```text
lost_found_ai/lib/features/chat/chat_screen.dart
lost_found_ai/lib/data/providers.dart
lost_found_ai/lib/data/chat_socket.dart
lost_found_api/app/Http/Controllers/Api/MatchController.php
lost_found_api/app/Models/ItemMatch.php
lost_found_api/app/Models/Message.php
```

Corrélation des données :

- un `match` relie `lost_item_id` et `found_item_id` ;
- chaque `message` appartient à un `match_id` et à un `sender_id` ;
- le JSON de chat contient `id`, `match_id`, `body`, `image_url`, `status`, `created_at`, `read_at`, `is_mine` et `sender` ;
- le JSON de match contient `viewer_role`, `last_message`, `last_message_at`, `last_message_is_mine` et `unread_count`.

Fonctionnement :

1. Le chargement initial récupère les 50 derniers messages, marque comme lus les messages entrants, puis connecte le WebSocket et démarre la poll.
2. Le chargement de l'historique utilise `before = premier message`, par pages de 50.
3. L'envoi passe par `POST /api/matches/{match}/messages`, en JSON ou multipart pour une image.
4. Les événements temps réel `message.sent` et `message.read` passent par Laravel Reverb sur le canal privé `private-match.{id}`.
5. Une poll HTTP de secours tourne toutes les 10 secondes ; elle resynchronise la page courante toutes les 40 secondes.
6. Les accusés de lecture sont appliqués uniquement aux messages envoyés par l'utilisateur courant.

Modération et confiance :

- le texte est modéré côté serveur avant stockage ;
- les messages bloqués ne sont pas sauvegardés, un `ModerationEvent` est créé ;
- un signalement crée aussi une `Claim` de type `COMPORTEMENT_ABUSIF` ;
- l'accès au chat dépend du score de confiance : `FULL` dès 40, `COORDINATION` de 30 à 39 avec quota de 5 messages, sinon `LOCKED`.

### 5.3 Images et similarité

Fichiers principaux :

```text
lost_found_ai/lib/core/perceptual_hash.dart
lost_found_ai/lib/core/ai/photo_similarity.dart
lost_found_ai/lib/widgets/photo_comparison_card.dart
lost_found_api/app/Services/ImageHashService.php
lost_found_api/app/Services/MatchingService.php
```

Fonctionnement :

1. La Flutter pick une image depuis la caméra ou la galerie.
2. Un dHash 64 bits est calculé sur l'appareil (grayscale 9×8, comparaison gauche/droite).
3. Le hash et le fichier sont envoyés en multipart avec l'annonce.
4. Le backend accepte le hash client ou le recalcule avec GD, puis le stocke dans `items.image_hash`.
5. Les URLs retournées sont relatives (`/storage/...`) et converties en URL absolues côté Flutter via `AppConfig.serverBaseUrl`.
6. La similarité combine dHash (Hamming) et histogramme RGB 4×4×4, avec un poids d'environ 62 % forme / 38 % couleur.
7. `PhotoComparisonCard` affiche ce score dans l'insight swipe et dans la feuille de vérification.

Limites actuelles :

- pas de modèle computer vision ;
- pas de détection de doublons exacts ;
- pas de modération d'image, seul le texte des messages est modéré ;
- le calcul est local/heuristique, mais le chargement des images distantes nécessite le réseau sauf `data:` URI.

### 5.4 Confiance, fraude et récompenses

- `TrustService` applique un système de points et d'événements immuables.
- `User` gèle certains gains pendant la période de probation.
- Une restitution confirmée deux fois crédite les deux parties, ajoute des points et génère un coupon.
- La roue des récompenses utilise 8 parts pondérées et un RNG local.
- Les coupons sont générés en PDF avec Dompdf puis envoyés par e-mail.
- L'arbitrage d'appel est une commande Artisan (`ResolveTrustAppeal`).

---

## 6. IA : ce qui est réellement utilisé

### Local / hors ligne

Aucun modèle TFLite, ONNX, Core ML, ML Kit ou OpenCV n'est embarqué. Les parties « IA » locales sont des algorithmes déterministes :

- `TextAgreementEngine` (Flutter) : normalisation, stopwords français, Dice, couverture, bigrams, contradictions ;
- `TextAgreementService` (Laravel) : même genre d'heuristique côté serveur ;
- `PhotoSimilarity` : dHash + histogramme couleur ;
- `MatchingService` : score pondéré image/localisation/temps/texte ;
- `TrustService`, modération lexicale et roue : règles et pondérations locales.

### External / cloud optionnel

Deux appels OpenAI existent, uniquement si `OPENAI_API_KEY` est défini :

- `gpt-4o-mini` pour les explications d'insight swipe ;
- `omni-moderation-latest` pour la modération de texte des messages.

Sans clé :

- l'insight swipe revient à l'heuristique locale ;
- la modération utilise le lexique local et applique une politique fail-open.

La connexion Google utilise l'API Google, mais c'est de l'authentification, pas de l'IA.

---

## 7. E-mails

### Mailpit (développement)

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

Interface : `http://localhost:8025`.

### SMTP réel

Utilisez un mot de passe d'application, jamais le mot de passe du compte. Tout reste dans `.env`.

```env
MAIL_MAILER=smtp
MAIL_SCHEME=tls
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_USERNAME=votre-adresse@gmail.com
MAIL_PASSWORD=mot-de-passe-application-16-caracteres
MAIL_FROM_ADDRESS="votre-adresse@gmail.com"
```

Après modification du `.env` :

```powershell
php artisan config:clear
```

---

## 8. Connexion Google Android

La connexion utilise un vrai compte Google via `google_sign_in`.

- Le client Web OAuth sert de `serverClientId` sur Android.
- Un client OAuth Android doit exister pour le package `fr.campus.lost_found_ai` avec le SHA-1 du certificat utilisé.
- Chaque machine peut avoir un SHA-1 différent, surtout pour les builds debug.

Récupérer le SHA-1 :

```powershell
cd lost_found_ai/android
.\gradlew signingReport
```

ou :

```powershell
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" `
  -alias androiddebugkey -storepass android -keypass android
```

Ajoutez ce SHA-1 au client OAuth Android dans Google Cloud Console. Si l'application OAuth est en mode test, ajoutez les comptes Google des testeurs.

---

## 9. Vérifications

### Backend

```powershell
cd lost_found_api
php artisan test
```

### Frontend

```powershell
cd lost_found_ai
flutter analyze
flutter test
```

### Build APK

```powershell
flutter build apk --release --split-per-abi --target-platform android-arm64 `
  --dart-define=API_BASE_URL=http://<IP_PC>:8000/api
```

Le fichier est généré dans :

```text
lost_found_ai/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

---

## 10. Dépannage

| Symptôme | Cause probable | Action |
| --- | --- | --- |
| `Connection refused` depuis l'émulateur | backend arrêté | lancer `php artisan serve --host=0.0.0.0` |
| Page blanche au démarrage Flutter | mauvaise `API_BASE_URL` | vérifier le `--dart-define` |
| Requête bloquée sur appareil physique | domaine HTTP clair absent | ajouter l'IP dans `network_security_config.xml` |
| Téléphone ne joint pas le PC sur hotspot | isolation client/client | changer de topology ou utiliser Tailscale / adb reverse |
| Google `DEVELOPER_ERROR (10)` | SHA-1 non enregistré | ajouter le SHA-1 dans Google Cloud Console |
| E-mails non reçus | mauvais SMTP | utiliser Mailpit ou un mot de passe d'application |
| Realtime chat inactif | Reverb non démarré | la poll HTTP prend le relais ; configurer Reverb si besoin |
| `Unauthenticated` | token expiré ou téléphone non vérifié | se reconnecter / vérifier le numéro |

---

## 11. Structure du dépôt

```text
.
├── README.md                    ce document
├── setup.ps1 / setup.cmd        scripts d'installation locale
├── lost_found_api/              API Laravel
└── lost_found_ai/               application Flutter
```
