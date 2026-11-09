import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/api_client.dart';
import '../../../data/providers.dart';

/// Service gérant la connexion avec Google.
///
/// Deux chemins, pour n'exiger qu'**une seule** étape de choix de compte :
///  * le flux natif `google_sign_in`, chemin par défaut : il ouvre la fenêtre
///    de connexion Google officielle (voir [googleServerClientId]) ;
///  * le sélecteur de comptes intégré, repli lorsqu'aucun ID client n'est
///    fourni (émulateur, démo).
class GoogleAuthHelper {
  /// ID client Web OAuth Google, passe comme `serverClientId` Android.
  ///
  /// Le flux natif ne peut reussir que si le build est enregistre dans Google
  /// Cloud Console : un client OAuth Android pour `fr.campus.lost_found_ai`
  /// associe a l'empreinte SHA-1 du certificat de signature. Sans cet
  /// enregistrement, `GoogleSignIn.signIn()` ouvre quand meme le selecteur de
  /// comptes natif puis echoue avec DEVELOPER_ERROR (10).
  ///
  /// L'ID par defaut est le client Web de l'application : on obtient ainsi la
  /// fenetre de connexion Google officielle. Pour un autre build :
  ///
  /// ```
  /// flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>
  /// ```
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '1084749713721-p4rtkavjbfl6efbpj2s643vdtjb0tkhh.apps.googleusercontent.com',
  );

  /// Le flux natif n'est tenté que pour un build enregistré (voir
  /// [googleServerClientId]) ; sinon le sélecteur intégré prend le relais.
  static bool get _isNativeGoogleSignInConfigured => googleServerClientId.isNotEmpty;

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: googleServerClientId.isEmpty ? null : googleServerClientId,
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
    if (!_isNativeGoogleSignInConfigured) {
      // Build non enregistré : le sélecteur natif échouerait de toute façon
      // après avoir demandé un compte. On propose directement le sélecteur
      // intégré, qui reste l'unique demande de compte.
      _showAccountSelectorSheet(
        context,
        ref,
        onLoadingStart: onLoadingStart,
        onLoadingEnd: onLoadingEnd,
      );
      return;
    }

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

  /// Sélecteur de compte Google intégré — chemin par défaut (émulateur, démo).
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
                    backgroundColor: Color(0xFF047857),
                    child: Text('F', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  title: const Text('Fares Jomaa', style: TextStyle(fontWeight: FontWeight.w600)),
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
                const Divider(),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF64748B),
                    child: Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 20),
                  ),
                  title: const Text('Utiliser un autre compte Google', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Saisir une autre adresse e-mail'),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showCustomEmailDialog(context, ref, onLoadingStart: onLoadingStart, onLoadingEnd: onLoadingEnd);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Boîte de dialogue pour saisir une adresse Google certifiée (@gmail.com).
  static void _showCustomEmailDialog(
    BuildContext context,
    WidgetRef ref, {
    VoidCallback? onLoadingStart,
    VoidCallback? onLoadingEnd,
  }) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        String? error;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Connexion Google',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Entrez l\'adresse Google (@gmail.com) à utiliser :',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.emailAddress,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'prenom.nom@gmail.com',
                      errorText: error,
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Seules les adresses @gmail.com sont acceptées.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final email = controller.text.trim().toLowerCase();
                    if (!email.endsWith('@gmail.com')) {
                      setDialogState(
                        () => error = 'Adresse @gmail.com requise.',
                      );
                      return;
                    }
                    Navigator.pop(dialogContext);
                    final localPart = email.split('@').first.replaceAll('.', ' ');
                    final name = localPart.isEmpty
                        ? 'Utilisateur Google'
                        : localPart[0].toUpperCase() + localPart.substring(1);
                    _loginWithAccount(
                      context,
                      ref,
                      email: email,
                      name: name,
                      googleId: 'google-user-${email.hashCode.abs()}',
                      onLoadingStart: onLoadingStart,
                      onLoadingEnd: onLoadingEnd,
                    );
                  },
                  child: const Text('Se connecter'),
                ),
              ],
            );
          },
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
