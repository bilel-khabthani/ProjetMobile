import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Rendu vectoriel natif du logo "G" multicolore de Google
/// sans dependance externe (SVG ou image).
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = math.min(w, h) / 2;
    final strokeWidth = radius * 0.42;

    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    final paintRed = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final paintYellow = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final paintGreen = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final paintBlue = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Arcs en radians
    // Rouge : Haut (~ 215deg a ~ 330deg)
    canvas.drawArc(rect, -math.pi * 0.72, math.pi * 0.58, false, paintRed);

    // Jaune : Haut-Gauche (~ 130deg a 215deg)
    canvas.drawArc(rect, -math.pi * 1.25, math.pi * 0.53, false, paintYellow);

    // Vert : Bas (~ 30deg a 130deg)
    canvas.drawArc(rect, math.pi * 0.15, math.pi * 0.6, false, paintGreen);

    // Bleu : Droite + barre horizontale
    canvas.drawArc(rect, -math.pi * 0.14, math.pi * 0.3, false, paintBlue);

    // Barre centrale bleue du 'G'
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;

    final barRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        center.dx - radius * 0.08,
        center.dy - strokeWidth / 2,
        radius * 1.08,
        strokeWidth,
      ),
      Radius.circular(strokeWidth * 0.2),
    );
    canvas.drawRRect(barRect, barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

