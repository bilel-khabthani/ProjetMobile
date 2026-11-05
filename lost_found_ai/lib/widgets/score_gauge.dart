import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

class ScoreGauge extends StatelessWidget {
  const ScoreGauge({
    super.key,
    required this.value,
    this.size = 96,
    this.strokeWidth = 8,
    this.color = AppColors.primary,
    this.secondaryColor,
    this.label,
    this.labelColor,
    this.animate = true,
    this.duration = const Duration(milliseconds: 1100),
  });

  final double value;
  final double size;
  final double strokeWidth;
  final Color color;
  final Color? secondaryColor;
  final String? label;
  final Color? labelColor;
  final bool animate;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final clamped = (value / 100).clamp(0.0, 1.0);

    if (!animate) {
      return _GaugeBody(
        progress: clamped,
        size: size,
        strokeWidth: strokeWidth,
        color: color,
        secondaryColor: secondaryColor,
        label: label,
        labelColor: labelColor,
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: clamped),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) => _GaugeBody(
        progress: progress,
        size: size,
        strokeWidth: strokeWidth,
        color: color,
        secondaryColor: secondaryColor,
        label: label,
        labelColor: labelColor,
      ),
    );
  }
}

class _GaugeBody extends StatelessWidget {
  const _GaugeBody({
    required this.progress,
    required this.size,
    required this.strokeWidth,
    required this.color,
    required this.secondaryColor,
    required this.label,
    required this.labelColor,
  });

  final double progress;
  final double size;
  final double strokeWidth;
  final Color color;
  final Color? secondaryColor;
  final String? label;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).round();
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _GaugePainter(
              progress: progress,
              color: color,
              secondaryColor: secondaryColor ?? color,
              strokeWidth: strokeWidth,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$percent',
                style: AppText.score.copyWith(
                  fontSize: size * 0.28,
                  color: labelColor ?? AppColors.textPrimary,
                ),
              ),
              if (label != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    label!,
                    style: AppText.caption.copyWith(
                      color: labelColor ?? AppColors.textTertiary,
                      fontSize: size * 0.085,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({
    required this.progress,
    required this.color,
    required this.secondaryColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color secondaryColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color.withValues(alpha: 0.13);
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;

    final shader = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: 3 * math.pi / 2,
      colors: [secondaryColor, color],
      transform: const GradientRotation(-math.pi / 2),
    ).createShader(rect);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = shader;

    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) {
    return old.progress != progress ||
        old.color != color ||
        old.secondaryColor != secondaryColor ||
        old.strokeWidth != strokeWidth;
  }
}
