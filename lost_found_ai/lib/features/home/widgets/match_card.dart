import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_strings.dart';
import '../../../core/router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/item.dart';
import '../../../data/models/item_match.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_icon.dart';
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
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.divider),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            ItemArtwork(
              category: match.foundItemCategory,
              width: 64,
              height: 64,
              borderRadius: AppRadius.sm,
              compact: true,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    match.foundItemTitle,
                    style: AppText.bodyStrong,
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
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      StatusPill(type: match.otherItemType, compact: true),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          match.finderName,
                          style: AppText.tiny.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
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
            ScoreGauge(
              value: match.scores.global,
              size: 46,
              strokeWidth: 5,
              color: scoreColor(match.scores.global),
              secondaryColor: scoreColor(
                match.scores.global,
              ).withValues(alpha: 0.5),
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
}

class MatchSpotlightCard extends StatelessWidget {
  const MatchSpotlightCard({
    super.key,
    required this.match,
    required this.onTap,
  });

  final ItemMatch match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 276,
      child: PressableScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.divider),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ItemArtwork(
                    category: match.foundItemCategory,
                    height: 126,
                    width: double.infinity,
                    borderRadius: 18,
                    compact: true,
                  ),
                  Positioned(
                    top: 9,
                    left: 9,
                    child: StatusPill(type: match.otherItemType, compact: true),
                  ),
                  Positioned(
                    top: 9,
                    right: 9,
                    child: MatchScoreBadge(score: match.scores.global),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 11, 6, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      match.foundItemTitle,
                      style: AppText.h3,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const AppIcon(
                          'map-point-linear',
                          size: 14,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            match.foundItemPlace,
                            style: AppText.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Avatar(
                          initials: match.finderInitials,
                          size: 26,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            match.finderName,
                            style: AppText.tiny.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (match.isVerified)
                          const VerifiedPill(compact: true)
                        else
                          Text(
                            _agoShort(match.minutesAgo),
                            style: AppText.tiny.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color scoreColor(double score) {
  if (score >= 80) return AppColors.found;
  if (score >= 65) return AppColors.accent;
  return AppColors.textTertiary;
}

String _agoShort(int minutes) {
  if (minutes < 60) return '${minutes.clamp(1, 59)} min';
  if (minutes < 1440) return '${minutes ~/ 60} h';
  return '${minutes ~/ 1440} j';
}

class NearbyFound {
  const NearbyFound({
    required this.title,
    required this.description,
    required this.placeLabel,
    required this.category,
    required this.score,
    required this.distanceKm,
    required this.timeHours,
    required this.finderName,
    required this.finderInitials,
    required this.occurredAt,
  });

  final String title;
  final String description;
  final String placeLabel;
  final ItemCategory category;
  final double score;
  final double distanceKm;
  final double? timeHours;
  final String finderName;
  final String finderInitials;
  final DateTime? occurredAt;

  factory NearbyFound.fromJson(Map<String, dynamic> data) {
    final item = (data['found_item'] as Map?)?.cast<String, dynamic>() ?? {};
    final user = (item['user'] as Map?)?.cast<String, dynamic>() ?? {};
    final name = (user['name'] as String?)?.trim() ?? 'Un membre du campus';
    final parts = name.split(RegExp(r'\s+'));
    final initials = parts.length >= 2
        ? '${parts.first[0]}${parts[1][0]}'.toUpperCase()
        : name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();

    return NearbyFound(
      title: (item['title'] as String?)?.trim().isNotEmpty == true
          ? item['title'] as String
          : 'Objet trouvé',
      description: (item['description'] as String?)?.trim() ?? '',
      placeLabel: (item['place_label'] as String?)?.trim().isNotEmpty == true
          ? item['place_label'] as String
          : 'Lieu non précisé',
      category: itemCategoryFromCode(item['category'] as String?),
      score: (data['global_score'] as num?)?.toDouble() ?? 0,
      distanceKm: (data['distance_km'] as num?)?.toDouble() ?? 0,
      timeHours: (data['time_hours'] as num?)?.toDouble(),
      finderName: name,
      finderInitials: initials,
      occurredAt: DateTime.tryParse(
        (item['occurred_at'] as String?) ?? '',
      )?.toLocal(),
    );
  }

  String get distanceLabel {
    if (distanceKm <= 0) return 'À proximité';
    if (distanceKm < 1) return '${(distanceKm * 1000).round()} m';
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  String get timeLabel {
    final hours = timeHours;
    if (hours == null) return 'Récemment';
    if (hours < 1) return 'Il y a moins d’une heure';
    if (hours < 24) return 'Il y a ${hours.round()} h';
    final days = (hours / 24).round();
    return 'Il y a $days j';
  }
}

class NearbyFoundTile extends StatelessWidget {
  const NearbyFoundTile({super.key, required this.item, required this.onTap});

  final NearbyFound item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            ItemArtwork(
              category: item.category,
              width: 60,
              height: 60,
              borderRadius: 16,
              compact: true,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: AppText.bodyStrong,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const AppIcon(
                        'map-point-linear',
                        size: 13,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          item.placeLabel,
                          style: AppText.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${item.distanceLabel} · ${item.timeLabel}',
                    style: AppText.tiny.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${item.score.round()} %',
                  style: AppText.label.copyWith(
                    color: scoreColor(item.score),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'affinité',
                  style: AppText.tiny.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 2),
            const AppIcon(
              'alt-arrow-right-linear',
              size: 16,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showNearbyFoundSheet(
  BuildContext context,
  NearbyFound item, {
  String? matchId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ItemArtwork(
                category: item.category,
                height: 176,
                width: double.infinity,
                borderRadius: 24,
                showLabel: true,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const StatusPill(type: ItemType.found),
                  const SizedBox(width: 8),
                  MatchScoreBadge(score: item.score),
                  const Spacer(),
                  Text(
                    item.distanceLabel,
                    style: AppText.caption,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(item.title, style: AppText.h2),
              if (item.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  item.description,
                  style: AppText.body.copyWith(color: AppColors.textSecondary),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 14),
              _InfoRow(
                icon: 'map-point-linear',
                label: item.placeLabel,
              ),
              const SizedBox(height: 8),
              _InfoRow(
                icon: 'clock-circle-linear',
                label: item.timeLabel,
              ),
              const SizedBox(height: 8),
              _InfoRow(
                icon: 'user-linear',
                label: 'Trouvé par ${item.finderName}',
              ),
              const SizedBox(height: 18),
              Text(
                'Cette annonce vous est suggérée. La conversation s’ouvre '
                'après vérification de la correspondance.',
                style: AppText.caption,
              ),
              const SizedBox(height: 16),
              AppButton(
                label: matchId != null
                    ? 'Voir la correspondance'
                    : 'Voir mes correspondances',
                iconName: 'chat-round-linear',
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  if (matchId != null) {
                    context.push(AppRoutes.matchDetail(matchId));
                  } else {
                    context.push(AppRoutes.messages);
                  }
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});

  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppIcon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: AppText.body)),
      ],
    );
  }
}
