import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import 'pressable_scale.dart';

enum AppButtonVariant { primary, secondary, ghost, success, danger }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.expand = true,
    this.height = 56,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final bool loading;
  final bool expand;
  final double height;

  @override
  Widget build(BuildContext context) {
    final visual = _AppButtonVisual(
      variant: variant,
      loading: loading,
      icon: icon,
    );

    final child = SizedBox(
      height: height,
      width: expand ? double.infinity : null,
      child: DecoratedBox(
        decoration: visual.decoration,
        child: Center(
          child: loading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      visual.foreground,
                    ),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (visual.icon != null) ...[
                      Icon(visual.icon, size: 20, color: visual.foreground),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        style: AppText.button.copyWith(
                          color: visual.foreground,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );

    final enabled = onPressed != null && !loading;
    return PressableScale(
      onTap: enabled ? onPressed : null,
      haptic: variant == AppButtonVariant.primary,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: enabled ? 1 : 0.5,
        child: child,
      ),
    );
  }
}

class _AppButtonVisual {
  const _AppButtonVisual({
    required this.variant,
    required this.loading,
    this.icon,
  });

  final AppButtonVariant variant;
  final bool loading;
  final IconData? icon;

  Color get foreground => switch (variant) {
    AppButtonVariant.primary => Colors.white,
    AppButtonVariant.secondary => AppColors.primary,
    AppButtonVariant.ghost => AppColors.textSecondary,
    AppButtonVariant.success => Colors.white,
    AppButtonVariant.danger => Colors.white,
  };

  BoxDecoration get decoration => switch (variant) {
    AppButtonVariant.primary => BoxDecoration(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(AppRadius.md),
      boxShadow: AppShadows.primary,
    ),
    AppButtonVariant.success => BoxDecoration(
      color: AppColors.found,
      borderRadius: BorderRadius.circular(AppRadius.md),
      boxShadow: const [
        BoxShadow(
          color: Color(0x402FB57C),
          blurRadius: 22,
          offset: Offset(0, 10),
        ),
      ],
    ),
    AppButtonVariant.danger => BoxDecoration(
      color: AppColors.danger,
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    AppButtonVariant.secondary => BoxDecoration(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(
        color: AppColors.primary.withValues(alpha: 0.35),
        width: 1.5,
      ),
    ),
    AppButtonVariant.ghost => BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
  };
}
