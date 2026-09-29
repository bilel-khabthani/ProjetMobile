import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_strings.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/providers.dart';
import '../../widgets/app_button.dart';
import 'widgets/auth_header.dart';
import 'widgets/social_buttons.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _acceptedTerms = false;
  bool _acceptedTermsError = false;
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _acceptedTermsError = false);
    final valid = _formKey.currentState?.validate() ?? false;
    if (!_acceptedTerms) {
      setState(() => _acceptedTermsError = true);
    }
    if (!valid || !_acceptedTerms) return;

    setState(() => _loading = true);
    await ref
        .read(sessionProvider.notifier)
        .signUp(
          name: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
        );
    if (!mounted) return;
    setState(() => _loading = false);
    context.go(AppRoutes.home);
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
                  title: AppStrings.signUpTitle,
                  subtitle: AppStrings.signUpSubtitle,
                ),
                const SizedBox(height: AppSpacing.xl),
                SocialAuthButtons(onPressed: () => context.go(AppRoutes.home)),
                const SizedBox(height: AppSpacing.xl),
                const OrDivider(label: AppStrings.orContinueWith),
                const SizedBox(height: AppSpacing.xl),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: AppStrings.fieldName,
                    hintText: AppStrings.fieldNameHint,
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? AppStrings.errorNameRequired
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: AppStrings.fieldEmail,
                    hintText: AppStrings.fieldEmailHint,
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
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: AppStrings.fieldPassword,
                    hintText: AppStrings.fieldPasswordHint,
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) => (value == null || value.length < 8)
                      ? AppStrings.errorPasswordShort
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _confirmController,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: AppStrings.fieldConfirm,
                    prefixIcon: const Icon(Icons.lock_reset_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: (value) => value != _passwordController.text
                      ? AppStrings.errorPasswordMismatch
                      : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                _TermsCheckbox(
                  value: _acceptedTerms,
                  showError: _acceptedTermsError,
                  onChanged: (value) => setState(() {
                    _acceptedTerms = value;
                    if (value) _acceptedTermsError = false;
                  }),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: AppStrings.createAccount,
                  loading: _loading,
                  onPressed: _submit,
                ),
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: TextButton(
                    onPressed: () => context.replace(AppRoutes.signIn),
                    child: Text(
                      AppStrings.alreadyHaveAccount,
                      style: AppText.label.copyWith(
                        color: AppColors.primary,
                        fontSize: 15,
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

class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({
    required this.value,
    required this.showError,
    required this.onChanged,
  });

  final bool value;
  final bool showError;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: (next) => onChanged(next ?? false),
                activeColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                "J’accepte les conditions d’utilisation et la politique de confidentialité.",
                style: AppText.caption.copyWith(fontSize: 13),
              ),
            ),
          ],
        ),
        if (showError)
          Padding(
            padding: const EdgeInsets.only(left: 36, top: 4),
            child: Text(
              AppStrings.errorTerms,
              style: AppText.caption.copyWith(color: AppColors.danger),
            ),
          ),
      ],
    );
  }
}
