import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

enum SceneVariant { search, link, shield }

class SceneArt extends StatelessWidget {
  const SceneArt({super.key, required this.variant, this.size = 200});

  final SceneVariant variant;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(variant);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: CustomPaint(painter: _ScenePainter(palette))),
          Container(
            width: size * 0.5,
            height: size * 0.5,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: palette.primary.withValues(alpha: 0.22),
                  blurRadius: size * 0.16,
                  offset: Offset(0, size * 0.06),
                ),
              ],
            ),
            child: Icon(
              _iconFor(variant),
              size: size * 0.24,
              color: palette.primary,
            ),
          ),
          if (variant == SceneVariant.link)
            Positioned(
              right: size * 0.06,
              top: size * 0.1,
              child: _SparkDot(color: palette.accent, size: size * 0.09),
            ),
          if (variant == SceneVariant.search)
            Positioned(
              right: size * 0.08,
              top: size * 0.14,
              child: _SparkDot(color: palette.accent, size: size * 0.075),
            ),
          if (variant == SceneVariant.shield)
            Positioned(
              right: size * 0.1,
              top: size * 0.12,
              child: _SparkDot(color: palette.accent, size: size * 0.07),
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

  static _ScenePalette _paletteFor(SceneVariant variant) => switch (variant) {
    SceneVariant.search => const _ScenePalette(
      AppColors.lost,
      Color(0xFFFFE0D3),
      AppColors.accent,
    ),
    SceneVariant.link => const _ScenePalette(
      AppColors.primary,
      Color(0xFFE0E4FF),
      AppColors.found,
    ),
    SceneVariant.shield => const _ScenePalette(
      AppColors.found,
      Color(0xFFD8F2E5),
      AppColors.accent,
    ),
  };
}

class _ScenePalette {
  const _ScenePalette(this.primary, this.soft, this.accent);

  final Color primary;
  final Color soft;
  final Color accent;
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
  const _ScenePainter(this.palette);

  final _ScenePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final blob = Paint()..color = palette.soft;
    final faint = Paint()..color = palette.soft.withValues(alpha: 0.55);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = palette.primary.withValues(alpha: 0.16);

    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.5),
      size.width * 0.42,
      blob,
    );

    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.24),
      size.width * 0.13,
      faint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.84, size.height * 0.7),
      size.width * 0.09,
      faint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.16, size.height * 0.82),
      size.width * 0.06,
      faint,
    );

    canvas.drawCircle(center, size.width * 0.5, ring);
    canvas.drawCircle(center, size.width * 0.36, ring);

    final dot = Paint()..color = palette.accent.withValues(alpha: 0.35);
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.06),
      size.width * 0.022,
      dot,
    );
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.94),
      size.width * 0.022,
      dot,
    );
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) => old.palette != palette;
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
            color: active ? AppColors.primary : AppColors.border,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        );
      }),
    );
  }
}
