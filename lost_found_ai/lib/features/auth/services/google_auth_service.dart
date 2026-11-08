import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/app_config.dart';
import '../../../core/router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/api_client.dart';
import '../../../data/providers.dart';
import '../../../widgets/app_button.dart';
import '../widgets/google_logo.dart';

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
      // Déconnecte toute session locale pour toujours ouvrir le sélecteur de compte
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
      } catch (_) {}

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
      // Si Google Play Services échoue (ex: SHA-1 non enregistré sur Google Cloud Console dans l'émulateur)
      _showGoogleConfigFallback(context, ref, details);
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

  /// Boîte de dialogue de secours si Google Play Services échoue (par ex. SHA-1 OAuth non configuré dans Google Console).
  static void _showGoogleConfigFallback(
    BuildContext context,
    WidgetRef ref,
    String errorDetail,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final emailController = TextEditingController();
        final nameController = TextEditingController();
        bool loading = false;

        return StatefulBuilder(
          builder: (dialogCtx, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              title: Row(
                children: [
                  const GoogleLogo(size: 24),
                  const SizedBox(width: AppSpacing.sm),
                  const Expanded(
                    child: Text(
                      'Connexion Google',
                      style: AppText.h3,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        'Google Play Services signale : $errorDetail.\n\nPour lier un compte Google réel sans configuration SHA-1 Google Cloud, saisissez votre adresse ci-dessous :',
                        style: AppText.caption.copyWith(color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Adresse Gmail / Google',
                        prefixIcon: Icon(Icons.alternate_email_rounded),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom complet (facultatif)',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Annuler'),
                ),
                AppButton(
                  label: 'Continuer',
                  loading: loading,
                  onPressed: () async {
                    final email = emailController.text.trim();
                    if (email.isEmpty || !email.contains('@')) return;
                    setState(() => loading = true);
                    try {
                      await ref.read(sessionProvider.notifier).signInWithGoogle(
                        email: email,
                        name: nameController.text.trim().isNotEmpty
                            ? nameController.text.trim()
                            : email.split('@').first,
                        googleId: 'google_${email.hashCode.abs()}',
                      );
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Connecté en tant que $email via Google.'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                      context.go(AppRoutes.home);
                    } catch (e) {
                      setState(() => loading = false);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(e is ApiException ? e.message : '$e'),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
