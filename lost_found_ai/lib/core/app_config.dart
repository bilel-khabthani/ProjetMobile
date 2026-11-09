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

  /// Met a true pour reafficher la demonstration hors ligne si le serveur
  /// n'est pas lance. A false en fonctionnement normal : les donnees
  /// proviennent alors de PostgreSQL via l'API Laravel.
  static const bool useMockData = bool.fromEnvironment(
    'USE_MOCK_DATA',
    defaultValue: false,
  );
}