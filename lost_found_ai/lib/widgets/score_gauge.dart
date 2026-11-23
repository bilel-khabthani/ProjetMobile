import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

class ScoreGauge extends StatelessWidget {
  const ScoreGauge({
    super.key,
    required this.value,
    this.size = 96,
    this.strokeWidth = 10,
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
    final colors = context.colors;
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
              foreground: secondaryColor ?? color,
              trackColor: colors.surfaceContainerHighest,
              strokeWidth: strokeWidth,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$percent',
                style: context.typography.headlineLarge?.copyWith(
                  fontSize: size * 0.28,
                  fontWeight: FontWeight.w700,
                  color: labelColor ?? colors.onSurface,
                ),
              ),
              if (label != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    label!,
                    style: context.typography.bodySmall?.copyWith(
                      color: labelColor ?? colors.onSurfaceVariant,
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
    required this.foreground,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color foreground;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = foreground;

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
        old.foreground != foreground ||
        old.trackColor != trackColor ||
        old.strokeWidth != strokeWidth;
  }
}
