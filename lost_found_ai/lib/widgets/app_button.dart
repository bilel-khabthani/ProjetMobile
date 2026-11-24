import 'package:flutter/material.dart';

import '../core/theme/app_motion.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_typography.dart';
import 'app_icon.dart';

enum AppButtonVariant { primary, secondary, ghost, success, danger }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.iconName,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.expand = true,
    this.height = 56,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final String? iconName;
  final AppButtonVariant variant;
  final bool loading;
  final bool expand;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final enabled = onPressed != null && !loading;
    final action = enabled ? onPressed : null;
    final foreground = _foreground(scheme, variant);
    final style = _style(scheme, variant, foreground);
    final content = _content(context, foreground);

    final Widget button = switch (variant) {
      AppButtonVariant.secondary => FilledButton.tonal(
        onPressed: action,
        style: style,
        child: content,
      ),
      AppButtonVariant.ghost => TextButton(
        onPressed: action,
        style: style,
        child: content,
      ),
      _ => FilledButton(onPressed: action, style: style, child: content),
    };

    return AnimatedSwitcher(
      duration: context.motion(AppMotion.micro),
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: SizedBox(
        key: ValueKey(loading ? 'loading' : 'idle'),
        height: height,
        width: expand ? double.infinity : null,
        child: button,
      ),
    );
  }

  Widget _content(BuildContext context, Color foreground) {
    if (loading) {
      return Semantics(
        label: '$label, chargement',
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation<Color>(foreground),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (iconName != null) ...[
          AppIcon(iconName!, size: 20, color: foreground),
          const SizedBox(width: AppSpacing.xs),
        ] else if (icon != null) ...[
          Icon(icon, size: 20, color: foreground),
          const SizedBox(width: AppSpacing.xs),
        ],
        Flexible(
          child: Text(
            label,
            style: context.typography.labelLarge?.copyWith(color: foreground),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  ButtonStyle _style(
    ColorScheme scheme,
    AppButtonVariant variant,
    Color foreground,
  ) {
    final base = ButtonStyle(
      foregroundColor: WidgetStateProperty.all<Color>(foreground),
      minimumSize: WidgetStateProperty.all<Size>(Size.fromHeight(height)),
      shape: WidgetStateProperty.all<OutlinedBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      textStyle: WidgetStateProperty.all<TextStyle>(AppText.button),
    );

    return switch (variant) {
      AppButtonVariant.primary => base.copyWith(
        backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
          return states.contains(WidgetState.disabled)
              ? scheme.onSurface.withValues(alpha: 0.12)
              : scheme.primary;
        }),
      ),
      AppButtonVariant.success => base.copyWith(
        backgroundColor: WidgetStateProperty.all<Color>(scheme.tertiary),
        foregroundColor: WidgetStateProperty.all<Color>(scheme.onTertiary),
      ),
      AppButtonVariant.danger => base.copyWith(
        backgroundColor: WidgetStateProperty.all<Color>(scheme.error),
        foregroundColor: WidgetStateProperty.all<Color>(scheme.onError),
      ),
      AppButtonVariant.secondary => base,
      AppButtonVariant.ghost => base.copyWith(
        backgroundColor: WidgetStateProperty.all<Color>(Colors.transparent),
        foregroundColor: WidgetStateProperty.all<Color>(scheme.primary),
      ),
    };
  }

  Color _foreground(ColorScheme scheme, AppButtonVariant variant) {
    return switch (variant) {
      AppButtonVariant.primary => scheme.onPrimary,
      AppButtonVariant.success => scheme.onTertiary,
      AppButtonVariant.danger => scheme.onError,
      AppButtonVariant.secondary => scheme.onSecondaryContainer,
      AppButtonVariant.ghost => scheme.primary,
    };
  }
}
