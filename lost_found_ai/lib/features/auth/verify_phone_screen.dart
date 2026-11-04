import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/api_client.dart';
import '../../data/providers.dart';
import '../../widgets/app_button.dart';
import 'widgets/auth_header.dart';

/// Module 1 (CDC 6.1) : verification obligatoire du numero de telephone.
/// Le compte est cree non verifie ; l'application impose cette saisie avant
/// tout acces aux services (garde du routeur + middleware verified-phone).
class VerifyPhoneScreen extends ConsumerStatefulWidget {
  const VerifyPhoneScreen({super.key});

  @override
  ConsumerState<VerifyPhoneScreen> createState() => _VerifyPhoneScreenState();
}

class _VerifyPhoneScreenState extends ConsumerState<VerifyPhoneScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  bool _loading = false;
  bool _resending = false;
  String? _error;
  String? _demoOtp;

  @override
  void initState() {
    super.initState();
    // En demo le serveur renvoie le code recu a l'inscription / a l'envoi.
    _demoOtp = ref.read(sessionProvider.notifier).consumeDemoOtp();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  String _messageOf(Object error) => error is ApiException
      ? error.message
      : 'Connexion impossible. Reessayez.';

  Future<void> _submit() async {
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
        const SnackBar(content: Text('Numero de telephone verifie !')),
      );
      // Le changement de session redeclenche la garde du routeur :
      // phoneVerified=true libere l'acces a l'application.
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
    final phone = ref.watch(sessionProvider)?.phone ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification du numero'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Se deconnecter',
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
                AuthHeader(
                  title: 'Un code vous attend',
                  subtitle: phone.isEmpty
                      ? 'Saisissez le code a six chiffres recu pour verifier votre compte.'
                      : 'Saisissez le code a six chiffres envoye au $phone pour activer votre compte.',
                ),
                const SizedBox(height: AppSpacing.xl),
                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  maxLength: 6,
                  style: AppText.h2.copyWith(letterSpacing: 10),
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'Code de verification',
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
                            'Demonstration : le code est $_demoOtp',
                            style: AppText.caption.copyWith(
                              color: AppColors.primary,
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
                  label: 'Verifier mon numero',
                  loading: _loading,
                  onPressed: _submit,
                ),
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: TextButton(
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
                ),
                Center(
                  child: TextButton(
                    onPressed: _loading ? null : _logout,
                    child: Text(
                      'Se deconnecter',
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
