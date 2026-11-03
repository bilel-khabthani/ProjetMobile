import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../data/models/item.dart';

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.type, this.compact = false});

  final ItemType type;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isLost = type == ItemType.lost;
    final color = isLost ? AppColors.lost : AppColors.found;
    final background = isLost ? AppColors.lostSoft : AppColors.foundSoft;
    final label = isLost ? 'Perdu' : 'Trouvé';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: compact ? 5 : 6),
          Text(
            label,
            style: AppText.caption.copyWith(
              color: Color.lerp(color, Colors.black, 0.22),
              fontWeight: FontWeight.w800,
              fontSize: compact ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }
}

class ScorePill extends StatelessWidget {
  const ScorePill({super.key, required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    final color = score >= 80
        ? AppColors.found
        : score >= 65
        ? AppColors.accent
        : AppColors.textTertiary;
    final background = score >= 80
        ? AppColors.foundSoft
        : score >= 65
        ? AppColors.accentSoft
        : AppColors.surfaceAlt;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '${score.round()} % de correspondance',
        style: AppText.caption.copyWith(
          color: Color.lerp(color, Colors.black, 0.2),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.initials,
    this.size = 44,
    this.color = AppColors.primary,
  });

  final String initials;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Text(
        initials,
        style: AppText.label.copyWith(
          color: Color.lerp(color, Colors.black, 0.15),
          fontSize: size * 0.34,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
