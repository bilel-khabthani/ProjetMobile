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

  /// ID client Web OAuth Google (utilise par GoogleSignIn sur Android pour
  /// obtenir un idToken officiel et sécurisé).
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '1084749713721-p4rtkavjbfl6efbpj2s643vdtjb0tkhh.apps.googleusercontent.com',
  );
}