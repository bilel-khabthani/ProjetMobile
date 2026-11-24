import 'package:flutter/material.dart';

import '../core/theme/app_motion.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';

class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class SkeletonLoader extends StatelessWidget {
  const SkeletonLoader({super.key, this.count = 2});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(count, (index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: context.colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              children: [
                const SkeletonBox(
                  width: 68,
                  height: 68,
                  borderRadius: AppRadius.md,
                ),
                const SizedBox(width: AppSpacing.sm),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 170, height: 14),
                      SizedBox(height: 8),
                      SkeletonBox(width: 120, height: 11),
                    ],
                  ),
                ),
                const SkeletonBox(width: 52, height: 52, borderRadius: 40),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.skeleton,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final shimmer = context.reduceMotion
            ? colors.surfaceContainerHighest
            : Color.lerp(
                colors.surfaceContainerLow,
                colors.surfaceContainerHighest,
                Curves.easeInOut.transform(_controller.value),
              );
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: shimmer,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}
