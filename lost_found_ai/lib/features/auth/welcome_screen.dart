import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_strings.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../widgets/app_button.dart';
import '../../widgets/scene_art.dart';
import 'services/google_auth_service.dart';
import 'widgets/social_buttons.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const SceneArt(variant: SceneVariant.link, size: 190),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                AppStrings.appName,
                style: AppText.display.copyWith(color: AppColors.primary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                AppStrings.appTagline,
                style: AppText.label.copyWith(
                  letterSpacing: 1.4,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                AppStrings.welcomeSubtitle,
                style: AppText.body.copyWith(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 3),
              GoogleSignInButton(
                loading: _googleLoading,
                onPressed: _onGoogleSignIn,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: AppStrings.createAccount,
                icon: Icons.person_add_alt_1_rounded,
                onPressed: () => context.push(AppRoutes.signUp),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: AppStrings.signIn,
                variant: AppButtonVariant.secondary,
                onPressed: () => context.push(AppRoutes.signIn),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'En continuant, vous acceptez les conditions d’utilisation.',
                style: AppText.caption,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}
