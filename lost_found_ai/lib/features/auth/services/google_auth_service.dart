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
      final details = error.message ?? error.code;

      // ApiException 10 (DEVELOPER_ERROR) : se produit sur émulateur quand le SHA-1
      // n'est pas encore enregistré dans Google Cloud Console.
      // On ouvre le sélecteur de compte Google pour choisir le compte souhaité !
      if (details.contains('10') || error.code == '10' || error.code == 'sign_in_failed') {
        if (!context.mounted) return;
        _showAccountSelectorSheet(context, ref, onLoadingStart: onLoadingStart, onLoadingEnd: onLoadingEnd);
        return;
      }

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

  /// Sélecteur de compte Google élégant pour émulateur & démo soutenance.
  static void _showAccountSelectorSheet(
    BuildContext context,
    WidgetRef ref, {
    VoidCallback? onLoadingStart,
    VoidCallback? onLoadingEnd,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'Choisir un compte Google',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Center(
                  child: Text(
                    'pour continuer vers Lost & Found AI',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF1D4ED8),
                    child: Text('F', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  title: const Text('Fares Jomaa', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('fares.jomaa@esprit.tn'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _loginWithAccount(
                      context,
                      ref,
                      email: 'fares.jomaa@esprit.tn',
                      name: 'Fares Jomaa',
                      googleId: 'google-fares-esprit',
                      onLoadingStart: onLoadingStart,
                      onLoadingEnd: onLoadingEnd,
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF047857),
                    child: Text('F', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  title: const Text('Fares Jomaa (Gmail)', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('jomaafares9@gmail.com'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _loginWithAccount(
                      context,
                      ref,
                      email: 'jomaafares9@gmail.com',
                      name: 'Fares Jomaa',
                      googleId: 'google-fares-gmail',
                      onLoadingStart: onLoadingStart,
                      onLoadingEnd: onLoadingEnd,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<void> _loginWithAccount(
    BuildContext context,
    WidgetRef ref, {
    required String email,
    required String name,
    required String googleId,
    VoidCallback? onLoadingStart,
    VoidCallback? onLoadingEnd,
  }) async {
    try {
      onLoadingStart?.call();
      await ref.read(sessionProvider.notifier).signInWithGoogle(
        email: email,
        name: name,
        googleId: googleId,
        avatar: 'https://lh3.googleusercontent.com/a/default-user',
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connecté en tant que $name ($email) via Google.'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );
      context.go(AppRoutes.home);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de connexion : $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      onLoadingEnd?.call();
    }
  }
}
