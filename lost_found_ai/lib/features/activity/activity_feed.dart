import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/item.dart';
import '../../data/models/item_match.dart';

enum ActivityKind { lost, found, pending, verified, recovered }

class ActivityEntry {
  const ActivityEntry({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.at,
    this.matchId,
    this.itemId,
  });

  final ActivityKind kind;
  final String title;
  final String subtitle;
  final DateTime at;
  final String? matchId;
  final String? itemId;

  String get iconName => switch (kind) {
    ActivityKind.lost => 'magnifer-linear',
    ActivityKind.found => 'hand-heart-linear',
    ActivityKind.pending => 'link-round-linear',
    ActivityKind.verified => 'verified-check-bold',
    ActivityKind.recovered => 'cup-star-linear',
  };

  Color get color => switch (kind) {
    ActivityKind.lost => AppColors.lost,
    ActivityKind.found => AppColors.found,
    ActivityKind.pending => AppColors.accent,
    ActivityKind.verified => AppColors.mintDark,
    ActivityKind.recovered => AppColors.primary,
  };
}

List<ActivityEntry> buildActivityFeed({
  required List<ItemMatch> matches,
  required List<Item> myItems,
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final entries = <ActivityEntry>[
    for (final item in myItems)
      ActivityEntry(
        kind: item.type == ItemType.lost ? ActivityKind.lost : ActivityKind.found,
        title: 'Annonce « ${item.title} » publiée',
        subtitle: '${item.place.isEmpty ? item.category.label : item.place}'
            ' · ${relativeTime(item.occurredAt, reference)}',
        at: item.occurredAt,
        itemId: item.id,
      ),
    for (final match in matches)
      ActivityEntry(
        kind: switch (match.status) {
          'RECOVERED' => ActivityKind.recovered,
          'VERIFIED' || 'CONTACTED' => ActivityKind.verified,
          _ => ActivityKind.pending,
        },
        title: 'Correspondance · ${match.foundItemTitle}',
        subtitle:
            '${match.scores.global.round()} % · ${matchStatusLabel(match)}',
        at: reference.subtract(Duration(minutes: match.minutesAgo)),
        matchId: match.id,
      ),
  ];

  entries.sort((a, b) => b.at.compareTo(a.at));
  return entries;
}

String matchStatusLabel(ItemMatch match) => switch (match.status) {
  'PENDING' => 'Vérification en attente',
  'VERIFIED' => 'Correspondance vérifiée',
  'CONTACTED' => 'Échange en cours',
  'RECOVERED' => 'Objet restitué',
  'REJECTED' => 'Correspondance refusée',
  _ => match.status,
};

String relativeTime(DateTime dt, [DateTime? now]) {
  final reference = now ?? DateTime.now();
  final diff = reference.difference(dt);
  if (diff.inMinutes < 1) return 'à l’instant';
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
  if (diff.inDays == 1) return 'hier';
  if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
  final day = dt.day.toString().padLeft(2, '0');
  final month = dt.month.toString().padLeft(2, '0');
  return '$day/$month/${dt.year}';
}
