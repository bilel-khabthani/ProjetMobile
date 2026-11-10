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
/// Utilise le flux natif de `google_sign_in` 7 (Credential Manager sur
/// Android) : le sélecteur de comptes officiel de Google s'ouvre par-dessus
/// l'application et aucun écran de connexion web intermédiaire n'est affiché.
class GoogleAuthHelper {
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  static Future<void>? _initialization;

  static const String _androidOAuthConfigurationMessage =
      'Google refuse la connexion : le client OAuth Android est mal configuré. '
      'Ajoutez le package fr.campus.lost_found_ai et l’empreinte SHA-1 du '
      'certificat de signature dans Google Cloud Console, puis réessayez.';

  /// Initialise le SDK une seule fois avec le client Web (`serverClientId`).
  ///
  /// Sur Android, un client OAuth Android doit aussi exister dans Google Cloud
  /// Console pour le package `fr.campus.lost_found_ai` et l'empreinte SHA-1 de
  /// la signature utilisée. Sans lui, la sélection du compte échoue.
  static Future<void> _ensureInitialized() {
    return _initialization ??= _googleSignIn
        .initialize(
          clientId: kIsWeb ? AppConfig.googleWebClientId : null,
          serverClientId: kIsWeb ? null : AppConfig.googleServerClientId,
        )
        .catchError((Object error) {
          _initialization = null;
          throw error;
        });
  }

  /// Ouvre le sélecteur de compte natif puis connecte l'utilisateur.
  static Future<void> handleGoogleSignIn(
    BuildContext context,
    WidgetRef ref, {
    VoidCallback? onLoadingStart,
    VoidCallback? onLoadingEnd,
  }) async {
    onLoadingStart?.call();

    try {
      await _ensureInitialized();
      if (!context.mounted) return;

      if (!_googleSignIn.supportsAuthenticate()) {
        _showError(
          context,
          'La connexion Google native n’est pas disponible sur cette plateforme. '
          'Utilisez l’application Android.',
        );
        return;
      }

      // Repart d'une session vierge pour toujours proposer le choix du compte.
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount account;
      try {
        account = await _googleSignIn.authenticate();
      } on GoogleSignInException catch (error) {
        final description = error.description ?? '';
        final configurationFailure =
            description.contains('[16]') ||
            description.toLowerCase().contains('reauth') ||
            error.code == GoogleSignInExceptionCode.clientConfigurationError;

        if (error.code == GoogleSignInExceptionCode.canceled) {
          debugPrint(
            'Google Sign-In interrompu : ${description.isEmpty ? error.code.name : description}',
          );
          if (!context.mounted) return;

          if (configurationFailure) {
            _showError(context, _androidOAuthConfigurationMessage);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Connexion Google annulée.')),
            );
          }
          return;
        }

        if (configurationFailure) {
          if (context.mounted) {
            _showError(context, _androidOAuthConfigurationMessage);
          }
          return;
        }

        rethrow;
      }

      if (!context.mounted) return;

      final String? idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        _showError(
          context,
          'Google n’a pas fourni de jeton d’identité. Vérifiez le '
          'serverClientId et le client OAuth Android dans Google Cloud Console.',
        );
        return;
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
          content: Text(
            'Connecté en tant que ${account.displayName ?? account.email} via Google.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      context.go(AppRoutes.home);
    } on GoogleSignInException catch (error) {
      final details = error.description ?? error.code.name;
      _showError(
        context,
        'Connexion Google impossible ($details). Vérifiez le package '
        'fr.campus.lost_found_ai, l’empreinte SHA-1 et le serverClientId dans '
        'Google Cloud Console.',
      );
    } on PlatformException catch (error) {
      final details = error.message ?? error.code;
      _showError(
        context,
        'Erreur Google Sign-In ($details). Vérifiez Google Play Services.',
      );
    } on Object catch (error) {
      final message = error is ApiException
          ? error.message
          : 'Échec de la connexion avec Google : $error';
      _showError(context, message);
    } finally {
      onLoadingEnd?.call();
    }
  }

  static void _showError(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.danger,
        duration: const Duration(seconds: 5),
      ),
    );
  }
}
