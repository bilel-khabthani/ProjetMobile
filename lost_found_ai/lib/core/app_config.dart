/// Configuration de l'application, regroupee au meme endroit pour que le
/// passage entre la demonstration hors ligne et l'API reelle soit explicite.
class AppConfig {
  const AppConfig._();

  /// Adresse de l'API Laravel.
  ///
  /// Valeur par defaut : l'emulateur Android voit la machine hote via
  /// l'alias 10.0.2.2. Pour un appareil physique, passer l'adresse IP du
  /// poste au lancement :
  ///   flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000/api
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );

  /// Met a true pour reafficher la demonstration hors ligne si le serveur
  /// n'est pas lance. A false en fonctionnement normal : les donnees
  /// proviennent alors de PostgreSQL via l'API Laravel.
  static const bool useMockData = bool.fromEnvironment(
    'USE_MOCK_DATA',
    defaultValue: false,
  );

  /// Diffusion temps reel via Laravel Reverb.
  ///
  /// La cle publique Reverb n'est pas un secret (elle identifie l'application
  /// aupres du serveur WebSocket). Pour un autre poste ou un appareil physique,
  /// surcharger l'hote au lancement :
  ///   flutter run --dart-define=REVERB_HOST=192.168.1.20
  static const String reverbAppKey = String.fromEnvironment(
    'REVERB_APP_KEY',
    defaultValue: 'xlxomr3qqdynftonmcxy',
  );

  static const String reverbHost = String.fromEnvironment(
    'REVERB_HOST',
    defaultValue: '10.0.2.2',
  );

  static const int reverbPort = int.fromEnvironment(
    'REVERB_PORT',
    defaultValue: 8081,
  );

  static const String reverbScheme = String.fromEnvironment(
    'REVERB_SCHEME',
    defaultValue: 'http',
  );

  /// Origine HTTP de l'API, sans le suffixe /api (utile pour /broadcasting/auth).
  static String get apiOrigin => Uri.parse(apiBaseUrl).origin;

  /// Racine du serveur (sans /api) pour les medias et images publiques.
  static String get serverBaseUrl =>
      apiBaseUrl.replaceAll(RegExp(r'/api/?$'), '');
}
