import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/api_client.dart';
import '../../../data/providers.dart';

/// Service gérant la vraie authentification avec Google via le plugin officiel `google_sign_in`.
class GoogleAuthHelper {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const <String>[
      'email',
      'profile',
    ],
  );

  /// Lance le flux réel de connexion Google Play Services / Google Sign-In.
  static Future<void> handleGoogleSignIn(
    BuildContext context,
    WidgetRef ref, {
    VoidCallback? onLoadingStart,
    VoidCallback? onLoadingEnd,
  }) async {
    try {
      // Déconnecte toute session locale pour toujours ouvrir le sélecteur de compte natif
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
        // En mode Android direct sans serverClientId, l'idToken n'est pas requis
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
      if (!context.mounted) return;
      final details = error.message ?? error.code;
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
