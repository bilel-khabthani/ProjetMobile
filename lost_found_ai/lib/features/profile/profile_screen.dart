import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_strings.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/item_match.dart';
import '../../data/providers.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/pressable_scale.dart';
import '../../widgets/status_pill.dart';

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
      await ref
          .read(sessionProvider.notifier)
          .updateMe(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            password: _changingPass ? _passController.text : null,
            passwordConfirmation: _changingPass
                ? _passConfirmController.text
                : null,
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
      final needsVerify = ref.read(sessionProvider)?.phoneVerified == false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            needsVerify
                ? 'Profil mis à jour. Un nouveau code de vérification vous attend.'
                : 'Profil mis à jour.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.danger,
        ),
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
            children: [
              Text(
                'MON COMPTE',
                style: AppText.eyebrow.copyWith(color: AppColors.primary),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: Text(AppStrings.profileTitle, style: AppText.h1)),
                  PressableScale(
                    onTap: () => context.push(AppRoutes.trust),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: const AppIcon(
                        'shield-check-linear',
                        size: 19,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                AppStrings.profileSubtitle,
                style: AppText.body.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 18),
              _ProfileHero(user: user),
              const SizedBox(height: 22),
              Text(
                'Informations personnelles',
                style: AppText.bodyStrong,
              ),
              const SizedBox(height: 10),
              _SectionCard(
                child: Column(
                  children: [
                    _Field(
                      controller: _nameController,
                      label: 'Prénom et nom',
                      icon: 'user-linear',
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requis' : null,
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      controller: _emailController,
                      label: 'Adresse e-mail',
                      icon: 'document-text-linear',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'E-mail invalide'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      controller: _phoneController,
                      label: 'Téléphone',
                      icon: 'smartphone-linear',
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      helper: 'Un changement demande une nouvelle vérification.',
                      validator: (v) {
                        final digits =
                            (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                        return digits.length >= 8 ? null : 'Numéro invalide';
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      value: _changingPass,
                      onChanged: (v) => setState(() => _changingPass = v),
                      contentPadding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
                      activeTrackColor: AppColors.primary,
                      title: Text(
                        'Modifier le mot de passe',
                        style: AppText.bodyStrong,
                      ),
                      subtitle: Text(
                        'Choisissez un mot de passe de 8 caractères minimum.',
                        style: AppText.tiny.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      secondary: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const AppIcon(
                          'lock-keyhole-linear',
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    if (_changingPass)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        child: Column(
                          children: [
                            _Field(
                              controller: _passController,
                              label: 'Nouveau mot de passe',
                              icon: 'lock-keyhole-linear',
                              obscure: true,
                              validator: (v) => (v == null || v.length < 8)
                                  ? '8 caractères minimum'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            _Field(
                              controller: _passConfirmController,
                              label: 'Confirmer le mot de passe',
                              icon: 'lock-keyhole-linear',
                              obscure: true,
                              validator: (v) => v != _passController.text
                                  ? 'Non identique'
                                  : null,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              PressableScale(
                onTap: () => context.push(AppRoutes.trust),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.divider),
                    boxShadow: AppShadows.card,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.foundSoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const AppIcon(
                          'cup-star-linear',
                          size: 21,
                          color: AppColors.mintDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mon score de confiance',
                              style: AppText.bodyStrong,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${(user?.reputation ?? 0).round()} points · '
                              '${user?.recoveredCount ?? 0} restitution(s)',
                              style: AppText.tiny.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const AppIcon(
                        'alt-arrow-right-linear',
                        size: 18,
                        color: AppColors.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              AppButton(
                label: 'Enregistrer les modifications',
                loading: _loading,
                onPressed: _loading ? null : _save,
              ),
              const SizedBox(height: 10),
              AppButton(
                label: AppStrings.profileLogout,
                variant: AppButtonVariant.ghost,
                iconName: 'logout-2-linear',
                onPressed: _logout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    final initials = user?.initials ?? 'BK';
    final name = user?.name ?? 'Compte';
    final email = user?.email ?? '';
    final phoneVerified = user?.phoneVerified ?? false;
    final reputation = (user?.reputation ?? 0).round();
    final recovered = user?.recoveredCount ?? 0;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF232B5C), AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppShadows.raised,
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -50,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: 2,
                        ),
                      ),
                      child: Avatar(
                        initials: initials,
                        size: 62,
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: AppText.h3.copyWith(color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            style: AppText.caption.copyWith(
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 7),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _HeroPill(
                                icon: phoneVerified
                                    ? 'verified-check-bold'
                                    : 'danger-triangle-linear',
                                label: phoneVerified
                                    ? 'Téléphone vérifié'
                                    : 'À vérifier',
                                color: phoneVerified
                                    ? const Color(0xFF9CF2D3)
                                    : const Color(0xFFFFD9A8),
                              ),
                              _HeroPill(
                                icon: 'star-linear',
                                label: '$reputation pts',
                                color: const Color(0xFFFFE3A8),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _HeroStat(
                        value: '$reputation',
                        label: 'Confiance',
                      ),
                    ),
                    _HeroDivider(),
                    Expanded(
                      child: _HeroStat(
                        value: '$recovered',
                        label: 'Restitutions',
                      ),
                    ),
                    _HeroDivider(),
                    Expanded(
                      child: _HeroStat(
                        value: phoneVerified ? 'Vérifié' : 'En attente',
                        label: 'Statut',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final String icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppText.tiny.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppText.h3.copyWith(color: Colors.white, fontSize: 18),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: AppText.tiny.copyWith(
            color: Colors.white.withValues(alpha: 0.62),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _HeroDivider extends StatelessWidget {
  const _HeroDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 26,
      color: Colors.white.withValues(alpha: 0.12),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppShadows.card,
      ),
      child: child,
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.helper,
    this.obscure = false,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? helper;
  final bool obscure;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscure,
      validator: validator,
      style: AppText.body.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        helperMaxLines: 2,
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: AppIcon(icon, size: 18, color: AppColors.textTertiary),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 44),
      ),
    );
  }
}
