import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';

class AppFadeSlideTransition extends PageTransitionsBuilder {
  const AppFadeSlideTransition();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final duration = context.motion(AppMotion.medium);
    if (duration == Duration.zero) return child;

    final curved = CurvedAnimation(
      parent: animation,
      curve: AppMotion.enter,
      reverseCurve: AppMotion.exit,
    );

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.018, 0),
        end: Offset.zero,
      ).animate(curved),
      child: FadeTransition(opacity: curved, child: child),
    );
  }
}

class AppStateTransition extends StatelessWidget {
  const AppStateTransition({
    super.key,
    required this.stateKey,
    required this.child,
  });

  final ValueKey<String> stateKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final duration = context.motion(AppMotion.short);
    if (duration == Duration.zero) return child;

    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: TweenAnimationBuilder<double>(
              key: stateKey,
              tween: Tween<double>(begin: 0, end: 1),
              duration: duration,
              curve: AppMotion.standard,
              builder: (context, value, _) {
                final alpha = value * (1 - value) * 4 * 0.06;
                return ColoredBox(
                  color: Theme.of(
                    context,
                  ).colorScheme.surface.withValues(alpha: alpha),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
