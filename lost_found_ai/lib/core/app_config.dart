import 'package:flutter/foundation.dart';

/// Configuration de l'application, regroupee au meme endroit pour que le
/// passage entre la demonstration hors ligne et l'API reelle soit explicite.
class AppConfig {
  const AppConfig._();

  /// Adresse de l'API Laravel.
  /// Automatiquement 'http://127.0.0.1:8000/api' sur le Web / Navigateur,
  /// et 'http://10.0.2.2:8000/api' sur l'émulateur Android.
  static String get apiBaseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (kIsWeb) return 'http://127.0.0.1:8000/api';
    return 'http://10.0.2.2:8000/api';
  }

  /// Racine du serveur, sans le prefixe `/api` : utilisee pour construire les
  /// URL des fichiers stockes (photos d'objets) renvoyees par l'API.
  static String get serverBaseUrl {
    final base = apiBaseUrl;
    return base.endsWith('/api')
        ? base.substring(0, base.length - '/api'.length)
        : base;
  }

  /// ID client Web OAuth Google (utilise par GoogleSignIn sur Android pour
  /// obtenir un idToken officiel et securise). Cette valeur provient de la
  /// branche `auth` et correspond au client Web du projet Google Cloud.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '722615003834-5bcdi1th4fvsjpk2fgn7ol95mqn655cj.apps.googleusercontent.com',
  );

  /// Client OAuth Web. GoogleSignIn exige un `clientId` sur le Web ; sur
  /// Android c'est le `serverClientId` qui permet d'obtenir un idToken.
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: googleServerClientId,
  );

  /// Met a true pour reafficher la demonstration hors ligne si le serveur
  /// n'est pas lance. A false en fonctionnement normal : les donnees
  /// proviennent alors de PostgreSQL via l'API Laravel.
  static const bool useMockData = bool.fromEnvironment(
    'USE_MOCK_DATA',
    defaultValue: false,
  );
}