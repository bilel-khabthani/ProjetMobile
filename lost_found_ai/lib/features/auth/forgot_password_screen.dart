import 'dart:async';
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

/// Écran de réinitialisation de mot de passe par code OTP envoyé par e-mail.
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
  bool _resending = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  int _resendCooldown = 0;
  Timer? _timer;

  String? _error;
  String? _info;
  String? _demoOtp;

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 45);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  String _messageOf(Object error) => error is ApiException
      ? error.message
      : 'Impossible de joindre le serveur. Réessayez.';

  Future<void> _requestCode({bool isResend = false}) async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Veuillez saisir une adresse e-mail valide.');
      return;
    }

    setState(() {
      if (isResend) {
        _resending = true;
      } else {
        _loading = true;
      }
      _error = null;
      _info = null;
    });

    try {
      final otp = await ref
          .read(sessionProvider.notifier)
          .forgotPassword(email: email);
      if (!mounted) return;

      _startCooldown();
      setState(() {
        _codeSent = true;
        _demoOtp = otp;
        _info = 'Un code de vérification OTP a été envoyé par e-mail à $email.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isResend
                ? 'Nouveau code OTP envoyé par e-mail.'
                : 'Code OTP envoyé à votre adresse e-mail.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = _messageOf(error));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _resending = false;
        });
      }
    }
  }

  Future<void> _reset() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Le code OTP doit comporter exactement 6 chiffres.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(sessionProvider.notifier).resetPassword(
        email: _emailController.text.trim(),
        code: code,
        password: _passwordController.text,
        passwordConfirmation: _confirmController.text,
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mot de passe réinitialisé avec succès ! Connectez-vous.'),
          backgroundColor: AppColors.success,
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

  void _changeEmail() {
    setState(() {
      _codeSent = false;
      _codeController.clear();
      _passwordController.clear();
      _confirmController.clear();
      _demoOtp = null;
      _info = null;
      _error = null;
    });
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
                  title: 'Mot de passe oublié ?',
                  subtitle: _codeSent
                      ? 'Consultez votre boîte e-mail, saisissez le code OTP reçu et choisissez un nouveau mot de passe.'
                      : 'Indiquez votre adresse e-mail. Nous vous enverrons un code de vérification OTP par e-mail.',
                ),
                const SizedBox(height: AppSpacing.xl),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: _codeSent
                      ? TextInputAction.next
                      : TextInputAction.done,
                  enabled: !_codeSent,
                  onFieldSubmitted: (_) {
                    if (!_codeSent) _requestCode();
                  },
                  decoration: InputDecoration(
                    labelText: 'Adresse e-mail',
                    prefixIcon: const Icon(Icons.alternate_email_rounded),
                    suffixIcon: _codeSent
                        ? TextButton(
                            onPressed: _changeEmail,
                            child: const Text('Modifier'),
                          )
                        : null,
                  ),
                ),
                if (_codeSent) ...[
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    maxLength: 6,
                    style: AppText.h2.copyWith(letterSpacing: 8),
                    decoration: const InputDecoration(
                      labelText: 'Code de vérification OTP',
                      hintText: '123456',
                      counterText: '',
                      prefixIcon: Icon(Icons.pin_outlined),
                    ),
                  ),
                  if (_demoOtp != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            'Mode démo : votre code est $_demoOtp',
                            style: AppText.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        icon: _resending
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh_rounded, size: 16),
                        label: Text(
                          _resendCooldown > 0
                              ? 'Renvoyer dans ${_resendCooldown}s'
                              : 'Renvoyer le code par e-mail',
                        ),
                        onPressed: (_resendCooldown > 0 || _resending)
                            ? null
                            : () => _requestCode(isResend: true),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Nouveau mot de passe',
                      hintText: '8 caractères minimum',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    validator: (v) => (v == null || v.length < 8)
                        ? '8 caractères minimum'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _confirmController,
                    obscureText: _obscureConfirm,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _reset(),
                    decoration: InputDecoration(
                      labelText: 'Confirmer le nouveau mot de passe',
                      prefixIcon: const Icon(Icons.lock_reset_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(
                          () => _obscureConfirm = !_obscureConfirm,
                        ),
                      ),
                    ),
                    validator: (v) => v != _passwordController.text
                        ? 'Les mots de passe ne correspondent pas'
                        : null,
                  ),
                ],
                if (_info != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.mail_outline_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            _info!,
                            style: AppText.caption.copyWith(color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.dangerLight,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 18,
                          color: AppColors.danger,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            _error!,
                            style: AppText.caption.copyWith(color: AppColors.danger),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: _codeSent
                      ? 'Réinitialiser le mot de passe'
                      : 'Envoyer le code OTP par e-mail',
                  icon: _codeSent ? Icons.check_circle_outline_rounded : Icons.send_rounded,
                  loading: _loading,
                  onPressed: _codeSent ? _reset : () => _requestCode(),
                ),
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: TextButton(
                    onPressed: () => context.go(AppRoutes.signIn),
                    child: Text(
                      'Retour à la connexion',
                      style: AppText.label.copyWith(color: AppColors.primary),
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
