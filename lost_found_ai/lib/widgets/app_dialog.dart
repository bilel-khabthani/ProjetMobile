import 'package:flutter/material.dart';

import '../core/theme/app_motion.dart';
import '../core/theme/app_spacing.dart';

Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? backgroundColor,
  EdgeInsetsGeometry margin = const EdgeInsets.all(24),
  String? semanticLabel,
}) {
  final reduceMotion = context.reduceMotion;
  final colors = Theme.of(context).colorScheme;

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: semanticLabel ?? 'Dialogue',
    barrierColor: colors.scrim.withValues(alpha: 0.42),
    transitionDuration: context.motion(AppMotion.dialog),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Semantics(
        label: semanticLabel,
        container: true,
        child: Center(
          child: Padding(
            padding: margin,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Material(
                color: backgroundColor ?? colors.surfaceContainerLow,
                elevation: backgroundColor == null ? 2 : 0,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                child: SafeArea(child: builder(context)),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      if (reduceMotion) return child;

      final curved = CurvedAnimation(
        parent: animation,
        curve: AppMotion.pop,
        reverseCurve: AppMotion.exit,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}
