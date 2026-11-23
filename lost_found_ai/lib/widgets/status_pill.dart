import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';
import '../data/models/item.dart';

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.type, this.compact = false});

  final ItemType type;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isLost = type == ItemType.lost;
    final background = isLost
        ? colors.primaryContainer
        : colors.tertiaryContainer;
    final foreground = isLost
        ? colors.onPrimaryContainer
        : colors.onTertiaryContainer;
    final dot = isLost ? colors.primary : colors.tertiary;
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
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          SizedBox(width: compact ? 5 : 6),
          Text(
            label,
            style: context.typography.bodySmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
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
    final colors = context.colors;
    final strong = score >= 80;
    final medium = score >= 65;
    final foreground = strong
        ? colors.onTertiaryContainer
        : medium
        ? colors.onSecondaryContainer
        : colors.onSurfaceVariant;
    final background = strong
        ? colors.tertiaryContainer
        : medium
        ? colors.secondaryContainer
        : colors.surfaceContainerHighest;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '${score.round()} % de correspondance',
        style: context.typography.bodySmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
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
    final colors = context.colors;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surfaceContainerHighest,
        border: Border.all(color: colors.outlineVariant, width: 1.5),
      ),
      child: Text(
        initials,
        style: context.typography.labelMedium?.copyWith(
          color: color,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
