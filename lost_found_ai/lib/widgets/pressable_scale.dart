import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_motion.dart';

class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
    this.haptic = true,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final bool haptic;
  final HitTestBehavior behavior;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = context.reduceMotion;
    final pressed = reduceMotion ? false : _pressed;

    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.lightImpact();
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: pressed ? widget.scale : 1,
        duration: context.motion(AppMotion.micro),
        curve: AppMotion.standard,
        child: AnimatedOpacity(
          opacity: pressed ? 0.92 : 1,
          duration: context.motion(AppMotion.micro),
          child: widget.child,
        ),
      ),
    );
  }
}
