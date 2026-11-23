import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_strings.dart';
import '../../core/router.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api_client.dart';
import '../../data/providers.dart';
import '../../widgets/app_button.dart';
import 'services/google_auth_service.dart';
import 'widgets/auth_header.dart';
import 'widgets/social_buttons.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'amina@campus.fr');
  final _passwordController = TextEditingController(text: 'campus2026');

  bool _obscure = true;
  bool _loading = false;
  bool _googleLoading = false;

  void _onGoogleSignIn() {
    GoogleAuthHelper.handleGoogleSignIn(
      context,
      ref,
      onLoadingStart: () => setState(() => _googleLoading = true),
      onLoadingEnd: () {
        if (mounted) setState(() => _googleLoading = false);
      },
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _messageOf(Object error) => error is ApiException
      ? error.message
      : 'Connexion impossible. Reessayez.';

  /// Remplit les champs avec le compte de demonstration (numero deja verifie)
  /// puis se connecte directement : aucun numero reel n'est demande.
  Future<void> _useDemoAccount() async {
    _emailController.text = AppStrings.demoAccountEmail;
    _passwordController.text = AppStrings.demoAccountPassword;
    FocusScope.of(context).unfocus();
    await _submit();
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    setState(() => _loading = true);
    try {
      await ref
          .read(sessionProvider.notifier)
          .signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      if (!mounted) return;
      // La garde du routeur impose /verify-phone si le numero n'est pas
      // verifie (CDC 6.1), sinon ouvre l'application.
      context.go(AppRoutes.home);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_messageOf(error))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xs,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AuthHeader(
                  title: AppStrings.signInTitle,
                  subtitle: AppStrings.signInSubtitle,
                ),
                const SizedBox(height: AppSpacing.lg),
                _DemoAccountCard(onUse: _useDemoAccount),
                const SizedBox(height: AppSpacing.xl),
                SocialAuthButtons(
                  loading: _googleLoading,
                  onGooglePressed: _onGoogleSignIn,
                ),
                const SizedBox(height: AppSpacing.xl),
                const OrDivider(label: AppStrings.orContinueWith),
                const SizedBox(height: AppSpacing.xl),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: AppStrings.fieldEmail,
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    final valid = text.contains('@') && text.contains('.');
                    return valid ? null : AppStrings.errorEmailInvalid;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: AppStrings.fieldPassword,
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (value) => (value == null || value.length < 8)
                      ? AppStrings.errorPasswordShort
                      : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push(AppRoutes.forgotPassword),
                    child: const Text('Mot de passe oublié ?'),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: AppStrings.signIn,
                  loading: _loading,
                  onPressed: _submit,
                ),
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: TextButton(
                    onPressed: () => context.replace(AppRoutes.signUp),
                    child: Text(
                      '${AppStrings.noAccountYet} ${AppStrings.createAccount}',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Encart d'acces rapide au compte de demonstration : les identifiants sont
/// visibles et un seul bouton connecte l'utilisateur sans numero de telephone.
class _DemoAccountCard extends StatelessWidget {
  const _DemoAccountCard({required this.onUse});

  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bolt_rounded,
                  size: 18,
                  color: context.colors.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  AppStrings.demoAccountTitle,
                  style: context.typography.titleMedium?.copyWith(
                    color: context.colors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${AppStrings.demoAccountEmail} · ${AppStrings.demoAccountPassword}',
              style: context.typography.bodyMedium?.copyWith(
                color: context.colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              AppStrings.demoAccountBody,
              style: context.typography.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: onUse,
              icon: const Icon(Icons.bolt_rounded, size: 18),
              label: Text(AppStrings.useDemoAccount),
            ),
          ],
        ),
      ),
    );
  }
}
