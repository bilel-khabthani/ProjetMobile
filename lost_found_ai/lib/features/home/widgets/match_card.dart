import 'package:flutter/material.dart';

import '../../../core/app_strings.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/item.dart';
import '../../../data/models/item_match.dart';
import '../../../widgets/photo_placeholder.dart';
import '../../../widgets/status_pill.dart';

class MatchCard extends StatelessWidget {
  const MatchCard({
    super.key,
    required this.match,
    required this.onTap,
    this.heroTag,
  });

  final ItemMatch match;
  final VoidCallback onTap;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final textTheme = context.typography;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Hero(
            tag: heroTag ?? 'match-photo-${match.id}',
            child: PhotoPlaceholder(
              category: match.foundItemCategory,
              size: 68,
              borderRadius: AppRadius.md,
              showLabel: false,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  match.foundItemTitle,
                  style: textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${AppStrings.matchFoundAt(match.foundItemPlace)} · ${_ago(match.minutesAgo)}',
                  style: textTheme.bodySmall,
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
                        style: textTheme.bodySmall,
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
          _MatchScore(
            score: match.scores.global,
            scheme: scheme,
            textTheme: textTheme,
          ),
        ],
      ),
    );
  }

  static String _ago(int minutes) {
    if (minutes < 1) return AppStrings.justNow;
    if (minutes < 60) return AppStrings.minutesAgo(minutes);
    return AppStrings.hoursAgo(minutes ~/ 60);
  }
}

class _MatchScore extends StatelessWidget {
  const _MatchScore({
    required this.score,
    required this.scheme,
    required this.textTheme,
  });

  final double score;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final color = score >= 80
        ? scheme.scoreHigh
        : score >= 50
        ? scheme.scoreMedium
        : scheme.scoreLow;
    final value = (score / 100).clamp(0.0, 1.0);
    return Column(
      children: [
        SizedBox(
          width: 52,
          height: 52,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: value,
                strokeWidth: 6,
                color: color,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
              Text(
                '${score.round()}',
                style: textTheme.labelLarge?.copyWith(color: scheme.onSurface),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text('score', style: textTheme.bodySmall?.copyWith(fontSize: 10)),
      ],
    );
  }
}
