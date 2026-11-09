import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/app_config.dart';
import '../../../core/router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/api_client.dart';
import '../../../data/providers.dart';

/// Service gérant la connexion avec Google.
///
/// Uniquement le flux natif `google_sign_in` : la fenêtre de connexion Google
/// officielle. C'est elle qui affiche les comptes déjà utilisés sur l'appareil
/// et propose « Utiliser un autre compte » — aucun compte de démonstration
/// n'est fabriqué côté application, l'adresse provient toujours d'un vrai
/// compte Google.
class GoogleAuthHelper {
  /// Le flux natif ne peut reussir que si le build est enregistre dans Google
  /// Cloud Console : un client OAuth Android pour `fr.campus.lost_found_ai`
  /// associe a l'empreinte SHA-1 du certificat de signature. Sans cet
  /// enregistrement, `GoogleSignIn.signIn()` ouvre quand meme le selecteur de
  /// comptes natif puis echoue avec DEVELOPER_ERROR (10).
  ///
  /// Les identifiants viennent de [AppConfig] et peuvent etre surcharges au
  /// lancement :
  ///
  /// ```
  /// flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>
  /// ```
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? AppConfig.googleWebClientId : null,
    serverClientId: kIsWeb ? null : AppConfig.googleServerClientId,
    scopes: const <String>[
      'email',
      'profile',
    ],
  );

  /// Ouvre l'unique étape de choix de compte puis connecte l'utilisateur.
  static Future<void> handleGoogleSignIn(
    BuildContext context,
    WidgetRef ref, {
    VoidCallback? onLoadingStart,
    VoidCallback? onLoadingEnd,
  }) async {
    try {
      // Déconnecte toute session native pour que la fenêtre Google s'ouvre
      // systématiquement (elle liste les comptes de l'appareil).
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      // Ouvre la boîte de dialogue native Google
      final GoogleSignInAccount? account = await _googleSignIn.signIn();

      if (account == null) {
        // L'utilisateur a fermé ou annulé la fenêtre de connexion Google
        return;
      }

      onLoadingStart?.call();

      String? idToken;
      try {
        final auth = await account.authentication;
        idToken = auth.idToken;
      } catch (_) {
        // L'API accepte les données de profil lorsque le jeton n'est pas disponible.
      }

      await ref.read(sessionProvider.notifier).signInWithGoogle(
        idToken: idToken,
        email: account.email,
        name: account.displayName ?? account.email.split('@').first,
        googleId: account.id,
        avatar: account.photoUrl,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connecté en tant que ${account.displayName ?? account.email} via Google.'),
          backgroundColor: AppColors.success,
        ),
      );
      context.go(AppRoutes.home);
    } on PlatformException catch (error) {
      // Le sélecteur natif vient de s'afficher : on n'ouvre jamais un second
      // sélecteur de compte par-dessus (c'était le double affichage). L'échec
      // est signalé simplement, à charge de l'équipe de finaliser
      // l'enregistrement OAuth (voir [googleServerClientId]).
      final details = error.message ?? error.code;
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur Google Sign-In ($details). Vérifiez Google Play Services.'),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 4),
        ),
      );
    } on Object catch (error) {
      if (!context.mounted) return;
      final message = error is ApiException
          ? error.message
          : 'Échec de la connexion avec Google : $error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      onLoadingEnd?.call();
    }
  }
}
