import 'package:flutter/material.dart';

import '../../../core/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/item.dart';
import '../../../data/models/item_match.dart';
import '../../../widgets/photo_placeholder.dart';
import '../../../widgets/pressable_scale.dart';
import '../../../widgets/score_gauge.dart';
import '../../../widgets/status_pill.dart';

class MatchCard extends StatelessWidget {
  const MatchCard({super.key, required this.match, required this.onTap});

  final ItemMatch match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            PhotoPlaceholder(
              category: match.foundItemCategory,
              size: 68,
              borderRadius: AppRadius.md,
              showLabel: false,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    match.foundItemTitle,
                    style: AppText.h3,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${AppStrings.matchFoundAt(match.foundItemPlace)} · ${_ago(match.minutesAgo)}',
                    style: AppText.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      StatusPill(type: ItemType.found, compact: true),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          match.finderName,
                          style: AppText.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Column(
              children: [
                ScoreGauge(
                  value: match.scores.global,
                  size: 52,
                  strokeWidth: 6,
                  color: _scoreColor(match.scores.global),
                  secondaryColor: _scoreColor(match.scores.global)
                      .withValues(alpha: 0.55),
                ),
                const SizedBox(height: 2),
                Text('score', style: AppText.caption.copyWith(fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _ago(int minutes) {
    if (minutes < 1) return AppStrings.justNow;
    if (minutes < 60) return AppStrings.minutesAgo(minutes);
    return AppStrings.hoursAgo(minutes ~/ 60);
  }

  static Color _scoreColor(double score) {
    if (score >= 80) return AppColors.found;
    if (score >= 65) return AppColors.accent;
    return AppColors.textTertiary;
  }
}
