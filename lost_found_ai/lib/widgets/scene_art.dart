import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';

enum SceneVariant { search, link, shield }

class SceneArt extends StatelessWidget {
  const SceneArt({super.key, required this.variant, this.size = 200});

  final SceneVariant variant;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final primary = switch (variant) {
      SceneVariant.search || SceneVariant.link => colors.primary,
      SceneVariant.shield => colors.tertiary,
    };
    final soft = switch (variant) {
      SceneVariant.search => colors.primaryContainer,
      SceneVariant.link => colors.secondaryContainer,
      SceneVariant.shield => colors.tertiaryContainer,
    };
    final accent = switch (variant) {
      SceneVariant.search || SceneVariant.shield => colors.secondary,
      SceneVariant.link => colors.tertiary,
    };

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _ScenePainter(
                soft: soft,
                faint: colors.surfaceContainerHighest,
                line: colors.outlineVariant,
                dot: accent,
              ),
            ),
          ),
          Container(
            width: size * 0.5,
            height: size * 0.5,
            decoration: BoxDecoration(
              color: colors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Icon(_iconFor(variant), size: size * 0.24, color: primary),
          ),
          if (variant == SceneVariant.link)
            Positioned(
              right: size * 0.06,
              top: size * 0.1,
              child: _SparkDot(color: accent, size: size * 0.09),
            ),
          if (variant == SceneVariant.search)
            Positioned(
              right: size * 0.08,
              top: size * 0.14,
              child: _SparkDot(color: accent, size: size * 0.075),
            ),
          if (variant == SceneVariant.shield)
            Positioned(
              right: size * 0.1,
              top: size * 0.12,
              child: _SparkDot(color: accent, size: size * 0.07),
            ),
        ],
      ),
    );
  }

  static IconData _iconFor(SceneVariant variant) => switch (variant) {
    SceneVariant.search => Icons.travel_explore_rounded,
    SceneVariant.link => Icons.auto_awesome_rounded,
    SceneVariant.shield => Icons.verified_user_rounded,
  };
}

class _SparkDot extends StatelessWidget {
  const _SparkDot({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _ScenePainter extends CustomPainter {
  const _ScenePainter({
    required this.soft,
    required this.faint,
    required this.line,
    required this.dot,
  });

  final Color soft;
  final Color faint;
  final Color line;
  final Color dot;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final blob = Paint()..color = soft;
    final faintPaint = Paint()..color = faint;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = line;

    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.5),
      size.width * 0.42,
      blob,
    );

    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.24),
      size.width * 0.13,
      faintPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.84, size.height * 0.7),
      size.width * 0.09,
      faintPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.16, size.height * 0.82),
      size.width * 0.06,
      faintPaint,
    );

    canvas.drawCircle(center, size.width * 0.5, ring);
    canvas.drawCircle(center, size.width * 0.36, ring);

    final dotPaint = Paint()..color = dot;
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.06),
      size.width * 0.022,
      dotPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.94),
      size.width * 0.022,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) =>
      old.soft != soft ||
      old.faint != faint ||
      old.line != line ||
      old.dot != dot;
}

class ProgressDots extends StatelessWidget {
  const ProgressDots({
    super.key,
    required this.count,
    required this.activeIndex,
  });

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final active = index == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 26 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? colors.primary : colors.outlineVariant,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        );
      }),
    );
  }
}
