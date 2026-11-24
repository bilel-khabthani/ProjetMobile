import 'package:flutter/material.dart';

import '../core/theme/app_motion.dart';
import '../core/theme/app_spacing.dart';

Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool showHandle = true,
  Color? backgroundColor,
  String? semanticLabel,
}) {
  final colors = Theme.of(context).colorScheme;

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: backgroundColor ?? colors.surfaceContainerLow,
    barrierColor: colors.scrim.withValues(alpha: 0.32),
    elevation: 1,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    sheetAnimationStyle: AnimationStyle(
      duration: context.motion(AppMotion.sheet),
      reverseDuration: context.motion(AppMotion.short),
    ),
    builder: (context) => Semantics(
      label: semanticLabel,
      container: true,
      child: AnimatedPadding(
        duration: context.motion(AppMotion.short),
        curve: AppMotion.standard,
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showHandle) ...[
              const SizedBox(height: AppSpacing.xs),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ],
            Flexible(child: builder(context)),
          ],
        ),
      ),
    ),
  );
}
