import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/pressable_scale.dart';

/// Boutons d'action du deck : passer, ouvrir l'analyse IA, valider.
class SwipeActionBar extends StatelessWidget {
  const SwipeActionBar({
    super.key,
    required this.onPass,
    required this.onInsight,
    required this.onLike,
    this.enabled = true,
  });

  final VoidCallback onPass;
  final VoidCallback onInsight;
  final VoidCallback onLike;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ActionButton(
          label: 'Passer',
          icon: Icons.close_rounded,
          color: AppColors.danger,
          background: AppColors.surface,
          onTap: enabled ? onPass : null,
        ),
        const SizedBox(width: AppSpacing.xl),
        _ActionButton(
          label: 'Analyse IA',
          icon: Icons.auto_awesome_rounded,
          color: Colors.white,
          background: AppColors.primary,
          size: 66,
          elevated: true,
          onTap: enabled ? onInsight : null,
        ),
        const SizedBox(width: AppSpacing.xl),
        _ActionButton(
          label: "C'est à moi",
          icon: Icons.favorite_rounded,
          color: Colors.white,
          background: AppColors.found,
          onTap: enabled ? onLike : null,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.background,
    this.size = 58,
    this.elevated = false,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color background;
  final double size;
  final bool elevated;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PressableScale(
            onTap: onTap,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: background,
                shape: BoxShape.circle,
                border: background == AppColors.surface
                    ? Border.all(
                        color: color.withValues(alpha: 0.28),
                        width: 1.5,
                      )
                    : null,
                boxShadow: elevated
                    ? AppShadows.primary
                    : const [
                        BoxShadow(
                          color: Color(0x141F1B2E),
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
              ),
              child: Icon(icon, color: color, size: size * 0.42),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppText.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
