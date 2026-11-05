import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/api_client.dart';
import '../../data/providers.dart';
import '../../widgets/app_button.dart';
import 'widgets/auth_header.dart';

/// Mot de passe oublie (CDC 7.2) : envoi d'un code de reinitialisation,
/// puis changement du mot de passe. En demo le serveur renvoie le code.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _codeSent = false;
  bool _loading = false;
  String? _error;
  String? _info;
  String? _demoOtp;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String _messageOf(Object error) => error is ApiException
      ? error.message
      : 'Connexion impossible. Reessayez.';

  Future<void> _requestCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Adresse e-mail invalide.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      final otp = await ref
          .read(sessionProvider.notifier)
          .forgotPassword(email: email);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _demoOtp = otp;
        _info = otp == null
            ? 'Si un compte existe, un code a ete envoye.'
            : null;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = _messageOf(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reset() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(sessionProvider.notifier)
          .resetPassword(
            email: _emailController.text.trim(),
            code: _codeController.text.trim(),
            password: _passwordController.text,
            passwordConfirmation: _confirmController.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mot de passe reinitialise. Connectez-vous.'),
        ),
      );
      context.go(AppRoutes.signIn);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = _messageOf(error));
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
                AuthHeader(
                  title: 'Mot de passe oublie ?',
                  subtitle: _codeSent
                      ? 'Saisissez le code recu puis choisissez un nouveau mot de passe.'
                      : 'Indiquez votre e-mail : nous vous envoyons un code de reinitialisation.',
                ),
                const SizedBox(height: AppSpacing.xl),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: _codeSent
                      ? TextInputAction.next
                      : TextInputAction.done,
                  enabled: !_codeSent,
                  decoration: const InputDecoration(
                    labelText: 'Adresse e-mail',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                ),
                if (_codeSent) ...[
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    maxLength: 6,
                    style: AppText.h2.copyWith(letterSpacing: 10),
                    decoration: const InputDecoration(
                      labelText: 'Code de reinitialisation',
                      hintText: '000000',
                      counterText: '',
                      prefixIcon: Icon(Icons.pin_outlined),
                    ),
                  ),
                  if (_demoOtp != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Demonstration : le code est $_demoOtp',
                      style: AppText.caption.copyWith(color: AppColors.primary),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nouveau mot de passe',
                      hintText: '8 caracteres minimum',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                    validator: (v) => (v == null || v.length < 8)
                        ? '8 caracteres minimum'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _confirmController,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _reset(),
                    decoration: const InputDecoration(
                      labelText: 'Confirmer le mot de passe',
                      prefixIcon: Icon(Icons.lock_reset_rounded),
                    ),
                    validator: (v) => v != _passwordController.text
                        ? 'Mots de passe non identiques'
                        : null,
                  ),
                ],
                if (_info != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(_info!, style: AppText.caption),
                ],
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _error!,
                    style: AppText.caption.copyWith(color: AppColors.danger),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: _codeSent
                      ? 'Reinitialiser le mot de passe'
                      : 'Envoyer le code',
                  loading: _loading,
                  onPressed: _codeSent ? _reset : _requestCode,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
