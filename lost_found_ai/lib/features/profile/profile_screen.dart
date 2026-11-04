import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

import '../../data/providers.dart';
import '../../widgets/photo_placeholder.dart';
import '../../data/models/item.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passController = TextEditingController();
  final _passConfirmController = TextEditingController();

  bool _loading = false;
  bool _changingPass = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(sessionProvider);
    if (user != null) {
      _nameController.text = user.name;
      _emailController.text = user.email;
      _phoneController.text = user.phone;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passController.dispose();
    _passConfirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(sessionProvider.notifier).updateMe(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _changingPass ? _passController.text : null,
        passwordConfirmation: _changingPass ? _passConfirmController.text : null,
        phone: _phoneController.text.trim(),
      );
      if (_changingPass) {
        setState(() {
          _changingPass = false;
          _passController.clear();
          _passConfirmController.clear();
        });
      }
      if (!mounted) return;
      HapticFeedback.lightImpact();
      // Un changement de numero re-impose la verification : la garde du
      // routeur redirige alors vers l'ecran OTP (CDC 6.1).
      final needsVerify = ref.read(sessionProvider)?.phoneVerified == false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            needsVerify
                ? 'Profil mis a jour. Un nouveau code de verification vous attend.'
                : 'Profil mis a jour.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    HapticFeedback.mediumImpact();
    try {
      await ref.read(sessionProvider.notifier).logout();
    } catch (_) {}
    // Purge les donnees de l'ancienne session pour qu'aucun ecran ne les
    // re-affiche apres reconnexion d'un autre compte.
    ref
      ..invalidate(matchesProvider)
      ..invalidate(myItemsProvider)
      ..invalidate(trustProvider)
      ..invalidate(nearbyFoundProvider);
    if (!mounted) return;
    context.go(AppRoutes.welcome);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
            tooltip: 'Se déconnecter',
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Center(
                child: PhotoPlaceholder(
                  initials: user?.initials ?? 'BK',
                  size: 88,
                  category: ItemCategory.bag,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Prénom et nom'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Adresse e-mail'),
                validator: (v) => (v == null || !v.contains('@')) ? 'E-mail invalide' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Téléphone',
                  helperText: 'Un changement demande une nouvelle verification.',
                ),
                validator: (v) {
                  final digits = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                  return digits.length >= 8 ? null : 'Numero invalide';
                },
              ),
              const SizedBox(height: AppSpacing.md),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.workspace_premium_outlined),
                title: const Text('Mon score de confiance'),
                subtitle: Text(
                  '${(user?.reputation ?? 0).round()} points',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push(AppRoutes.trust),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.card_giftcard_rounded, color: AppColors.accent),
                title: const Text('Mes Récompenses & Bons Partenaires'),
                subtitle: const Text('Coupons Glovo, Yassir & Roue de la Chance'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push(AppRoutes.rewards),
              ),
              const SizedBox(height: AppSpacing.lg),
              SwitchListTile.adaptive(
                title: const Text('Modifier le mot de passe'),
                value: _changingPass,
                onChanged: (v) => setState(() => _changingPass = v),
              ),
              if (_changingPass) ...[
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _passController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Nouveau mot de passe'),
                  validator: (v) => (v == null || v.length < 8) ? '8 caractères minimum' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _passConfirmController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirmer le mot de passe'),
                  validator: (v) => v != _passController.text ? 'Non identique' : null,
                ),
              ],
              const SizedBox(height: AppSpacing.xxxl),
              FilledButton(
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}