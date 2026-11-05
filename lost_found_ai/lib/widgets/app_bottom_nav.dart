import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/router.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import 'app_icon.dart';

enum AppTab { home, explore, messages, profile }

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.active});

  final AppTab active;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
        boxShadow: AppShadows.nav,
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 2),
        child: SizedBox(
          height: 74,
          child: Row(
            children: [
              _NavItem(
                icon: 'home-2-linear',
                activeIcon: 'home-2-bold',
                label: 'Accueil',
                selected: active == AppTab.home,
                onTap: () => context.go(AppRoutes.home),
              ),
              _NavItem(
                icon: 'compass-linear',
                activeIcon: 'compass-bold',
                label: 'Explorer',
                selected: active == AppTab.explore,
                onTap: () => context.go(AppRoutes.explore),
              ),
              _PublishItem(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  context.push(AppRoutes.publish);
                },
              ),
              _NavItem(
                icon: 'chat-round-linear',
                activeIcon: 'chat-round-bold',
                label: 'Messages',
                selected: active == AppTab.messages,
                onTap: () => context.go(AppRoutes.messages),
              ),
              _NavItem(
                icon: 'user-linear',
                activeIcon: 'user-bold',
                label: 'Profil',
                selected: active == AppTab.profile,
                onTap: () => context.go(AppRoutes.profile),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String icon;
  final String activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textTertiary;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (!selected) HapticFeedback.selectionClick();
            onTap();
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                width: 40,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primarySoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: AppIcon(
                  selected ? activeIcon : icon,
                  size: 22,
                  color: color,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: AppText.tiny.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PublishItem extends StatelessWidget {
  const _PublishItem({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        label: 'Publier une annonce',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Transform.translate(
                offset: const Offset(0, -16),
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF5B4DF5), AppColors.primary],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.surface, width: 4),
                    boxShadow: AppShadows.primary,
                  ),
                  child: const Center(
                    child: AppIcon(
                      'add-circle-bold',
                      size: 28,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -12),
                child: Text(
                  'Signaler',
                  style: AppText.tiny.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
