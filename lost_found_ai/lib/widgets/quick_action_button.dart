import 'package:flutter/material.dart';

import '../core/theme/app_motion.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';
import 'app_icon.dart';

class QuickActionButton extends StatelessWidget {
  const QuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final foreground = color ?? scheme.primary;
    final background = color == null
        ? scheme.secondaryContainer
        : scheme.surfaceContainerHigh;

    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      child: SizedBox(
        height: 64,
        child: FilledButton.tonal(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: background,
            foregroundColor: foreground,
            animationDuration: context.motion(AppMotion.micro),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            textStyle: context.typography.labelMedium,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(icon, color: foreground, size: 20),
              const SizedBox(height: AppSpacing.xxs),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
