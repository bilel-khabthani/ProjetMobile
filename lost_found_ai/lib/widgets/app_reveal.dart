import 'package:flutter/material.dart';

import '../core/theme/app_motion.dart';

class AppReveal extends StatelessWidget {
  const AppReveal({
    super.key,
    required this.index,
    required this.child,
    this.duration = AppMotion.medium,
    this.maxItems = AppMotion.maxStaggerItems,
    this.offset = const Offset(0, AppMotion.revealDistance),
  });

  final int index;
  final Widget child;
  final Duration duration;
  final int maxItems;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) return child;

    final delay = AppMotion.stagger(index, maxItems: maxItems);
    final total = duration + delay;
    final start = total.inMilliseconds == 0
        ? 0.0
        : delay.inMilliseconds / total.inMilliseconds;
    final interval = Interval(start, 1, curve: AppMotion.enter);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: context.motion(total),
      curve: Curves.linear,
      child: child,
      builder: (context, value, child) {
        final progress = interval.transform(value);
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: offset * (1 - progress),
            child: child,
          ),
        );
      },
    );
  }
}
