import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/api_client.dart';
import '../../data/providers.dart';
import '../../widgets/app_button.dart';
import 'widgets/auth_header.dart';

/// Module 1 (CDC 6.1) : vérification obligatoire du numéro de téléphone.
/// Le compte est créé non vérifié ; l'application impose cette saisie avant
/// tout accès aux services (garde du routeur + middleware verified-phone).
class VerifyPhoneScreen extends ConsumerStatefulWidget {
  const VerifyPhoneScreen({super.key});

  @override
  ConsumerState<VerifyPhoneScreen> createState() => _VerifyPhoneScreenState();
}

class _VerifyPhoneScreenState extends ConsumerState<VerifyPhoneScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _phoneInputController = TextEditingController();

  bool _loading = false;
  bool _resending = false;
  bool _needsPhone = false;
  String? _error;
  String? _demoOtp;

  @override
  void initState() {
    super.initState();
    final user = ref.read(sessionProvider);
    _needsPhone = user?.phone.isEmpty ?? true;
    if (!_needsPhone) {
      _phoneInputController.text = user?.phone ?? '';
    }
    // En démo le serveur renvoie le code reçu à l'inscription / à l'envoi.
    _demoOtp = ref.read(sessionProvider.notifier).consumeDemoOtp();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _phoneInputController.dispose();
    super.dispose();
  }

  String _messageOf(Object error) => error is ApiException
      ? error.message
      : 'Connexion impossible. Réessayez.';

  Future<void> _submitPhone() async {
    final phone = _phoneInputController.text.trim();
    if (phone.isEmpty || phone.length < 8) {
      setState(() => _error = 'Veuillez saisir un numéro de téléphone valide.');
      return;
    }

    final user = ref.read(sessionProvider);
    if (user == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(sessionProvider.notifier).updateMe(
        name: user.name,
        email: user.email,
        phone: phone,
      );
      if (!mounted) return;
      final otp = ref.read(sessionProvider.notifier).consumeDemoOtp();
      setState(() {
        _needsPhone = false;
        _demoOtp = otp;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Code de vérification envoyé par SMS.'),
          backgroundColor: AppColors.success,
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = _messageOf(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitCode() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Le code comporte 6 chiffres.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).verifyPhone(code: code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Numéro de téléphone vérifié !'),
          backgroundColor: AppColors.success,
        ),
      );
      // Le changement de session redéclenche la garde du routeur :
      // phoneVerified=true libère l'accès à l'application.
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = _messageOf(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      final otp = await ref.read(sessionProvider.notifier).resendOtp();
      if (!mounted) return;
      setState(() => _demoOtp = otp);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nouveau code envoyé.'),
          backgroundColor: AppColors.success,
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = _messageOf(error));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _logout() async {
    await ref.read(sessionProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final currentPhone = ref.watch(sessionProvider)?.phone ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vérification du numéro'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Se déconnecter',
            onPressed: _loading ? null : _logout,
          ),
        ],
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
                if (_needsPhone) ...[
                  const AuthHeader(
                    title: 'Ajoutez votre numéro',
                    subtitle:
                        'Pour des raisons de sécurité et d\'anti-fraude (CDC 6.1), un numéro vérifié est obligatoire pour utiliser les services.',
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  TextFormField(
                    controller: _phoneInputController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submitPhone(),
                    decoration: const InputDecoration(
                      labelText: 'Numéro de téléphone',
                      hintText: '+33 6 12 34 56 78',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _error!,
                      style: AppText.caption.copyWith(color: AppColors.danger),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: 'Envoyer le code de vérification',
                    icon: Icons.send_rounded,
                    loading: _loading,
                    onPressed: _submitPhone,
                  ),
                ] else ...[
                  AuthHeader(
                    title: 'Un code vous attend',
                    subtitle: currentPhone.isEmpty
                        ? 'Saisissez le code à six chiffres reçu pour vérifier votre compte.'
                        : 'Saisissez le code à six chiffres envoyé au $currentPhone pour activer votre compte.',
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  TextFormField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    maxLength: 6,
                    style: AppText.h2.copyWith(letterSpacing: 10),
                    onFieldSubmitted: (_) => _submitCode(),
                    decoration: const InputDecoration(
                      labelText: 'Code de vérification',
                      hintText: '000000',
                      counterText: '',
                      prefixIcon: Icon(Icons.sms_outlined),
                    ),
                  ),
                  if (_demoOtp != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.science_outlined,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Démonstration : le code est $_demoOtp',
                              style: AppText.caption.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
                    label: 'Vérifier mon numéro',
                    loading: _loading,
                    onPressed: _submitCode,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: _resending || _loading ? null : _resend,
                        child: _resending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                'Renvoyer le code',
                                style: AppText.label.copyWith(
                                  color: AppColors.primary,
                                ),
                              ),
                      ),
                      const Text(' • '),
                      TextButton(
                        onPressed: _loading ? null : () => setState(() => _needsPhone = true),
                        child: Text(
                          'Modifier le numéro',
                          style: AppText.label.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: TextButton(
                    onPressed: _loading ? null : _logout,
                    child: Text(
                      'Se déconnecter',
                      style: AppText.label.copyWith(
                        color: AppColors.textTertiary,
                      ),
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
