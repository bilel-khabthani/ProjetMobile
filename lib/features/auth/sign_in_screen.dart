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

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'yasmine@campus.fr');
  final _passwordController = TextEditingController(text: 'campus2026');

  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    setState(() => _loading = true);
    await ref
        .read(sessionProvider.notifier)
        .signIn(
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
                  title: AppStrings.signInTitle,
                  subtitle: AppStrings.signInSubtitle,
                ),
                const SizedBox(height: AppSpacing.xl),
                SocialAuthButtons(onPressed: () => context.go(AppRoutes.home)),
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
                    onPressed: () {},
                    child: Text(
                      'Mot de passe oublié ?',
                      style: AppText.label.copyWith(color: AppColors.primary),
                    ),
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
