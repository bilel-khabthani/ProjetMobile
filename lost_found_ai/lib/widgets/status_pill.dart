import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../data/models/item.dart';
import 'app_icon.dart';

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.type,
    this.compact = false,
    this.onTap,
  });

  final ItemType type;
  final bool compact;
  final GestureTapCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isLost = type == ItemType.lost;
    final color = isLost ? AppColors.lost : AppColors.found;
    final background = isLost ? AppColors.lostSoft : AppColors.foundSoft;
    final label = isLost ? 'Perdu' : 'Trouvé';

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: compact ? 4 : 5,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: AppText.tiny.copyWith(
                  color: Color.lerp(color, AppColors.textPrimary, 0.28),
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 10 : 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VerifiedPill extends StatelessWidget {
  const VerifiedPill({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: AppColors.foundSoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(
            'verified-check-bold',
            size: compact ? 12 : 14,
            color: AppColors.mintDark,
          ),
          const SizedBox(width: 4),
          Text(
            'Vérifié',
            style: AppText.tiny.copyWith(
              color: AppColors.mintDark,
              fontWeight: FontWeight.w800,
              fontSize: compact ? 10 : 11,
            ),
          ),
        ],
      ),
    );
  }
}

class MatchScoreBadge extends StatelessWidget {
  const MatchScoreBadge({super.key, required this.score});

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
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(
            score >= 80
                ? 'star-linear'
                : score >= 65
                ? 'bolt-linear'
                : 'question-circle-linear',
            size: 13,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            '${score.round()} %',
            style: AppText.tiny.copyWith(
              color: Color.lerp(color, AppColors.textPrimary, 0.3),
              fontWeight: FontWeight.w800,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

// Alias for backwards compatibility
@Deprecated('Use MatchScoreBadge instead')
class ScorePill extends StatelessWidget {
  const ScorePill({super.key, required this.score});

  final double score;

  @override
  Widget build(BuildContext context) => MatchScoreBadge(score: score);
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(color, Colors.white, 0.72)!,
            Color.lerp(color, Colors.white, 0.5)!,
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.28), width: 1.4),
      ),
      child: Text(
        initials,
        style: AppText.label.copyWith(
          color: Color.lerp(color, AppColors.textPrimary, 0.4),
          fontSize: size * 0.32,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
