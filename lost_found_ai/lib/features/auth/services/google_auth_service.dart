import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/api_client.dart';
import '../../../data/providers.dart';
import '../../../widgets/app_button.dart';
import '../widgets/google_logo.dart';

/// Service gérant le flux "Continuer avec Google".
/// Permet la sélection de compte Google et l'authentification transparente.
class GoogleAuthHelper {
  static Future<void> handleGoogleSignIn(
    BuildContext context,
    WidgetRef ref, {
    VoidCallback? onLoadingStart,
    VoidCallback? onLoadingEnd,
  }) async {
    // Affiche le sélecteur de compte Google pour choisir ou saisir l'adresse
    final selectedAccount = await showModalBottomSheet<_GoogleMockAccount>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _GoogleAccountPickerSheet(),
    );

    if (selectedAccount == null || !context.mounted) return;

    onLoadingStart?.call();
    try {
      await ref.read(sessionProvider.notifier).signInWithGoogle(
        email: selectedAccount.email,
        name: selectedAccount.name,
        googleId: selectedAccount.googleId,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connecté en tant que ${selectedAccount.name} via Google.'),
          backgroundColor: AppColors.success,
        ),
      );
      // Navigation vers l'application (la garde redirigera vers /verify-phone si nécessaire)
      context.go(AppRoutes.home);
    } on Object catch (error) {
      if (!context.mounted) return;
      final message = error is ApiException
          ? error.message
          : 'Échec de la connexion avec Google. Réessayez.';
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

class _GoogleMockAccount {
  const _GoogleMockAccount({
    required this.name,
    required this.email,
    required this.googleId,
  });

  final String name;
  final String email;
  final String googleId;
}

class _GoogleAccountPickerSheet extends StatefulWidget {
  const _GoogleAccountPickerSheet();

  @override
  State<_GoogleAccountPickerSheet> createState() => _GoogleAccountPickerSheetState();
}

class _GoogleAccountPickerSheetState extends State<_GoogleAccountPickerSheet> {
  final _customEmailController = TextEditingController();
  final _customNameController = TextEditingController();
  bool _showCustomForm = false;

  final List<_GoogleMockAccount> _accounts = const [
    _GoogleMockAccount(
      name: 'Amina Mansouri',
      email: 'amina.mansouri@gmail.com',
      googleId: 'google_1082736451928374',
    ),
    _GoogleMockAccount(
      name: 'Yasmine Benali',
      email: 'yasmine.benali@gmail.com',
      googleId: 'google_9182736450192834',
    ),
  ];

  @override
  void dispose() {
    _customEmailController.dispose();
    _customNameController.dispose();
    super.dispose();
  }

  void _submitCustom() {
    final email = _customEmailController.text.trim();
    final name = _customNameController.text.trim();
    if (email.isEmpty || !email.contains('@')) return;

    final account = _GoogleMockAccount(
      name: name.isEmpty ? email.split('@').first : name,
      email: email,
      googleId: 'google_${email.hashCode.abs()}',
    );
    Navigator.of(context).pop(account);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: AppSpacing.lg,
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              const GoogleLogo(size: 26),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Continuer avec Google',
                style: AppText.h3.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Choisissez un compte Google pour vous connecter à Lost&Found AI',
            style: AppText.caption,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (!_showCustomForm) ...[
            for (final acc in _accounts) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppColors.primarySoft,
                  child: Text(
                    acc.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(acc.name, style: AppText.body),
                subtitle: Text(acc.email, style: AppText.caption),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () => Navigator.of(context).pop(acc),
              ),
              const Divider(color: AppColors.divider),
            ],
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: AppColors.surfaceAlt,
                child: const Icon(Icons.person_add_alt_1_rounded, size: 20, color: AppColors.textSecondary),
              ),
              title: Text('Utiliser un autre compte', style: AppText.body),
              onTap: () => setState(() => _showCustomForm = true),
            ),
          ] else ...[
            TextFormField(
              controller: _customEmailController,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Adresse e-mail Google',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _customNameController,
              decoration: const InputDecoration(
                labelText: 'Nom complet (facultatif)',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Retour',
                    variant: AppButtonVariant.secondary,
                    onPressed: () => setState(() => _showCustomForm = false),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    label: 'Valider',
                    onPressed: _submitCustom,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

