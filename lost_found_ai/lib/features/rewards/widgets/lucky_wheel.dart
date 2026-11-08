import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/reward.dart';

class LuckyWheelWidget extends StatefulWidget {
  const LuckyWheelWidget({
    super.key,
    required this.onSpinRequested,
    this.isSpinning = false,
    this.canSpin = true,
  });

  final Future<SpinResult?> Function() onSpinRequested;
  final bool isSpinning;
  final bool canSpin;

  @override
  State<LuckyWheelWidget> createState() => _LuckyWheelWidgetState();
}

class _LuckyWheelWidgetState extends State<LuckyWheelWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  Animation<double>? _rotationAnimation;

  double _currentAngle = 0;
  bool _spinningLocally = false;

  // Configuration des 8 tranches : 100% Points avec probabilités décroissantes
  static final List<_SliceData> _slices = [
    const _SliceData(
      label: '+5 Pts',
      sublabel: '35% chance',
      color: Color(0xFF10B981),
      icon: Icons.add_circle_outline_rounded,
      textColor: Colors.white,
    ),
    const _SliceData(
      label: '+10 Pts',
      sublabel: '25% chance',
      color: Color(0xFF3B82F6),
      icon: Icons.bolt_rounded,
      textColor: Colors.white,
    ),
    const _SliceData(
      label: '+15 Pts',
      sublabel: '15% chance',
      color: Color(0xFF8B5CF6),
      icon: Icons.stars_rounded,
      textColor: Colors.white,
    ),
    const _SliceData(
      label: '+20 Pts',
      sublabel: '10% chance',
      color: Color(0xFF6366F1),
      icon: Icons.card_giftcard_rounded,
      textColor: Colors.white,
    ),
    const _SliceData(
      label: '+30 Pts',
      sublabel: '7% chance',
      color: Color(0xFFF59E0B),
      icon: Icons.military_tech_rounded,
      textColor: Colors.white,
    ),
    const _SliceData(
      label: '+50 Pts',
      sublabel: '4% chance',
      color: Color(0xFFF97316),
      icon: Icons.diamond_rounded,
      textColor: Colors.white,
    ),
    const _SliceData(
      label: '+75 Pts',
      sublabel: '3% chance',
      color: Color(0xFFEC4899),
      icon: Icons.workspace_premium_rounded,
      textColor: Colors.white,
    ),
    const _SliceData(
      label: 'JACKPOT',
      sublabel: '100 Pts (1%)',
      color: Color(0xFFEAB308),
      icon: Icons.emoji_events_rounded,
      textColor: Color(0xFF78350F),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _startSpin() async {
    if (!widget.canSpin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous avez déjà tourné la roue aujourd\'hui ! Revenez demain pour votre prochain tour.'),
          backgroundColor: AppColors.textSecondary,
        ),
      );
      return;
    }
    if (_spinningLocally || widget.isSpinning) return;

    setState(() => _spinningLocally = true);
    HapticFeedback.mediumImpact();

    try {
      final result = await widget.onSpinRequested();
      if (result == null) {
        setState(() => _spinningLocally = false);
        return;
      }

      final targetIndex = result.prizeIndex;
      final sliceSweep = (2 * math.pi) / _slices.length;

      // Calcul de l'angle pour que la tranche gagnante s'arrête exactement sous la flèche en haut (angle = -pi/2)
      // Flèche = angle de 270 deg (ou -90 deg). L'offset fait atterrir la tranche au milieu.
      final targetSliceCenter = (targetIndex * sliceSweep) + (sliceSweep / 2);
      final finalAngleNormalized = (1.5 * math.pi) - targetSliceCenter;

      // Ajoute 6 à 8 tours complets pour un effet spectaculaire
      const extraTurns = 6 * 2 * math.pi;
      final targetAngle = _currentAngle + extraTurns + (finalAngleNormalized - (_currentAngle % (2 * math.pi)));

      _rotationAnimation = Tween<double>(
        begin: _currentAngle,
        end: targetAngle,
      ).animate(
        CurvedAnimation(
          parent: _animController,
          curve: Curves.easeOutCubic,
        ),
      );

      _animController.reset();
      await _animController.forward();

      _currentAngle = targetAngle % (2 * math.pi);
      HapticFeedback.heavyImpact();

      if (mounted) {
        _showWinDialog(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _spinningLocally = false);
      }
    }
  }

  void _showWinDialog(SpinResult result) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final pts = result.prize.points;
        final isJackpot = pts >= 75;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: isJackpot ? const Color(0xFFFEF3C7) : AppColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isJackpot ? Icons.emoji_events_rounded : Icons.stars_rounded,
                    size: 42,
                    color: isJackpot ? const Color(0xFFD97706) : AppColors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  isJackpot ? '🌟 JACKPOT DU JOUR !' : '🎉 Félicitations !',
                  style: AppText.h2,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '+$pts Points',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Vos points ont été crédités sur votre compte !\nVous pouvez les utiliser dans la Boutique pour commander vos bons Glovo, Yassir ou Resto.',
                  style: AppText.caption,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Génial !'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const wheelSize = 280.0;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Flèche indicatrice au sommet de la roue
          const Icon(
            Icons.arrow_drop_down_rounded,
            size: 44,
            color: AppColors.danger,
          ),
          Transform.translate(
            offset: const Offset(0, -10),
            child: SizedBox(
              width: wheelSize,
              height: wheelSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Roue tournante
                  AnimatedBuilder(
                    animation: _animController,
                    builder: (context, child) {
                      final angle = _rotationAnimation?.value ?? _currentAngle;
                      return Transform.rotate(
                        angle: angle,
                        child: CustomPaint(
                          size: const Size(wheelSize, wheelSize),
                          painter: _WheelPainter(slices: _slices),
                        ),
                      );
                    },
                  ),

                  // Moyeu central avec bouton SPIN
                  GestureDetector(
                    onTap: _spinningLocally ? null : _startSpin,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.raised,
                        border: Border.all(
                          color: AppColors.primary,
                          width: 3.5,
                        ),
                      ),
                      child: Center(
                        child: !widget.canSpin
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.lock_clock_rounded,
                                    color: AppColors.textTertiary,
                                    size: 22,
                                  ),
                                  Text(
                                    'DEMAIN',
                                    style: AppText.caption.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textTertiary,
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              )
                            : _spinningLocally
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2.5),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.play_arrow_rounded,
                                        color: AppColors.primary,
                                        size: 26,
                                      ),
                                      Text(
                                        'SPIN',
                                        style: AppText.caption.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primary,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            onPressed: (!widget.canSpin || _spinningLocally) ? null : _startSpin,
            icon: Icon(widget.canSpin ? Icons.casino_rounded : Icons.lock_clock_rounded),
            label: Text(
              _spinningLocally
                  ? 'Tirage en cours...'
                  : widget.canSpin
                      ? 'Tourner la roue (1 fois par jour) !'
                      : 'Déjà tourné aujourd\'hui — Revenez demain !',
            ),
          ),
        ],
      ),
    );
  }
}

class _SliceData {
  const _SliceData({
    required this.label,
    required this.sublabel,
    required this.color,
    required this.icon,
    required this.textColor,
  });

  final String label;
  final String sublabel;
  final Color color;
  final IconData icon;
  final Color textColor;
}

class _WheelPainter extends CustomPainter {
  const _WheelPainter({required this.slices});

  final List<_SliceData> slices;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sweepAngle = (2 * math.pi) / slices.length;

    // Ombre extérieure de la roue
    final shadowPaint = Paint()
      ..color = Colors.black12
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(center, radius, shadowPaint);

    // Tranches
    for (int i = 0; i < slices.length; i++) {
      final slice = slices[i];
      final startAngle = i * sweepAngle;

      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      // Bordure de séparation blanche
      final borderPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        borderPaint,
      );

      // Texte et icône dans la tranche
      final textAngle = startAngle + (sweepAngle / 2);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(textAngle);

      final textSpan = TextSpan(
        text: '${slice.label}\n${slice.sublabel}',
        style: TextStyle(
          color: slice.textColor,
          fontWeight: FontWeight.w800,
          fontSize: 10,
          height: 1.1,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: radius * 0.45);

      textPainter.paint(
        canvas,
        Offset(radius * 0.45, -textPainter.height / 2),
      );

      canvas.restore();
    }

    // Cerclage extérieur doré / chromé
    final rimPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0;
    canvas.drawCircle(center, radius, rimPaint);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) => false;
}

