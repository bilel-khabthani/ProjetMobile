import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_strings.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../widgets/app_button.dart';
import '../../widgets/scene_art.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  static const List<_Slide> _slides = [
    _Slide(
      variant: SceneVariant.search,
      title: 'Vous avez perdu quelque chose ?',
      body: 'Déclarez-le en deux minutes. Nous cherchons pour vous, tout le campus.',
    ),
    _Slide(
      variant: SceneVariant.link,
      title: 'Le bon objet, au bon moment',
      body: 'Notre moteur compare les images, les lieux, les horaires et les descriptions pour trouver la correspondance.',
    ),
    _Slide(
      variant: SceneVariant.shield,
      title: 'Une mise en relation sécurisée',
      body: 'Une question secrète confirme l’identité du propriétaire avant tout échange.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _index == _slides.length - 1;

  void _next() {
    if (_isLast) {
      context.go(AppRoutes.welcome);
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.go(AppRoutes.welcome),
                child: Text(
                  AppStrings.onboardingSkip,
                  style: AppText.label.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.86, end: 1),
                          duration: const Duration(milliseconds: 520),
                          curve: Curves.easeOutBack,
                          builder: (context, scale, child) =>
                              Transform.scale(scale: scale, child: child),
                          child: SceneArt(variant: slide.variant, size: 220),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        Text(
                          slide.title,
                          style: AppText.h1,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          slide.body,
                          style: AppText.body.copyWith(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              child: Column(
                children: [
                  ProgressDots(count: _slides.length, activeIndex: _index),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: _isLast
                        ? AppStrings.onboardingStart
                        : AppStrings.onboardingNext,
                    onPressed: _next,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide {
  const _Slide({
    required this.variant,
    required this.title,
    required this.body,
  });

  final SceneVariant variant;
  final String title;
  final String body;
}
