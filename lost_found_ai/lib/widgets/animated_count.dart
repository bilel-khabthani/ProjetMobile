import 'package:flutter/material.dart';

import '../core/theme/app_motion.dart';

class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.textAlign,
    this.duration = AppMotion.counter,
  });

  final double value;
  final String Function(double value) format;
  final TextStyle? style;
  final TextAlign? textAlign;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final text = format(value);
    if (context.reduceMotion) {
      return Text(text, style: style, textAlign: textAlign);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: context.motion(duration),
      curve: AppMotion.enter,
      builder: (context, animatedValue, _) => Text(
        format(animatedValue),
        style: style,
        textAlign: textAlign,
      ),
    );
  }
}
