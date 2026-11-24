import 'package:flutter/material.dart';

import '../core/theme/app_motion.dart';
import '../core/theme/app_theme.dart';

class SuccessBadge extends StatelessWidget {
  const SuccessBadge({
    super.key,
    this.size = 72,
    this.color,
    this.icon = Icons.check_rounded,
    this.duration = AppMotion.long,
  });

  final double size;
  final Color? color;
  final IconData icon;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? context.colors.primary;
    final badge = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Icon(icon, size: size * 0.46, color: accent),
    );

    if (context.reduceMotion) return badge;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.72, end: 1),
      duration: context.motion(duration),
      curve: AppMotion.pop,
      child: badge,
      builder: (context, scale, child) => Transform.scale(
        scale: scale,
        child: Opacity(opacity: scale.clamp(0.0, 1.0), child: child),
      ),
    );
  }
}
