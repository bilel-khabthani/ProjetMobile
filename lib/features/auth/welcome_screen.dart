import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_strings.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../widgets/app_button.dart';
import '../../widgets/scene_art.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

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
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'En continuant, vous acceptez les conditions d’utilisation.',
                style: AppText.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
