import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_strings.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/item.dart';
import '../../data/models/item_match.dart';
import '../../data/providers.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/pressable_scale.dart';
import '../../widgets/skeleton.dart';
import 'activity_feed.dart';

enum _FeedFilter { all, matches, items }

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  _FeedFilter _filter = _FeedFilter.all;

  @override
  Widget build(BuildContext context) {
    final matches = ref.watch(matchesProvider);
    final myItems = ref.watch(myItemsProvider);
    final matchList = matches.valueOrNull ?? const <ItemMatch>[];
    final itemList = myItems.valueOrNull ?? const <Item>[];
    final feed = buildActivityFeed(matches: matchList, myItems: itemList);
    final visible = switch (_filter) {
      _FeedFilter.all => feed,
      _FeedFilter.matches =>
        feed.where((entry) => entry.matchId != null).toList(growable: false),
      _FeedFilter.items =>
        feed.where((entry) => entry.matchId == null).toList(growable: false),
    };
    final verifiedCount = matchList.where((match) => match.isVerified).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: () async {
            ref.invalidate(matchesProvider);
            ref.invalidate(myItemsProvider);
            try {
              await Future.wait([
                ref.read(matchesProvider.future),
                ref.read(myItemsProvider.future),
              ]);
            } catch (_) {
              // Les etats vides prennent le relais.
            }
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
            children: [
              Row(
                children: [
                  _CircleBack(onTap: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(AppRoutes.home);
                    }
                  }),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const AppIcon(
                          'bell-linear',
                          size: 15,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Notifications',
                          style: AppText.tiny.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'JOURNAL',
                style: AppText.eyebrow.copyWith(color: AppColors.primary),
              ),
              const SizedBox(height: 6),
              Text(AppStrings.activityTitle, style: AppText.h1),
              const SizedBox(height: 4),
              Text(
                AppStrings.activitySubtitle,
                style: AppText.body.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      icon: 'document-text-linear',
                      value: '${itemList.length}',
                      label: 'Annonces',
                      color: AppColors.primary,
                      background: AppColors.primarySoft,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatTile(
                      icon: 'link-round-linear',
                      value: '${matchList.length}',
                      label: 'Matches',
                      color: AppColors.accent,
                      background: AppColors.accentSoft,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatTile(
                      icon: 'verified-check-linear',
                      value: '$verifiedCount',
                      label: 'Vérifiés',
                      color: AppColors.mintDark,
                      background: AppColors.foundSoft,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _FilterTab(
                      label: 'Tout',
                      selected: _filter == _FeedFilter.all,
                      onTap: () => setState(() => _filter = _FeedFilter.all),
                    ),
                    const SizedBox(width: 8),
                    _FilterTab(
                      label: 'Correspondances',
                      selected: _filter == _FeedFilter.matches,
                      onTap: () =>
                          setState(() => _filter = _FeedFilter.matches),
                    ),
                    const SizedBox(width: 8),
                    _FilterTab(
                      label: 'Annonces',
                      selected: _filter == _FeedFilter.items,
                      onTap: () =>
                          setState(() => _filter = _FeedFilter.items),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (matches.isLoading || myItems.isLoading)
                const _ActivitySkeleton()
              else if (visible.isEmpty)
                const _ActivityEmpty()
              else
                _Timeline(entries: visible),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleBack extends StatelessWidget {
  const _CircleBack({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.divider),
          boxShadow: AppShadows.card,
        ),
        child: const AppIcon(
          'alt-arrow-left-linear',
          size: 20,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.background,
  });

  final String icon;
  final String value;
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(11),
            ),
            child: AppIcon(icon, size: 17, color: color),
          ),
          const SizedBox(height: 10),
          Text(value, style: AppText.h2.copyWith(fontSize: 20)),
          Text(
            label,
            style: AppText.tiny.copyWith(
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppText.label.copyWith(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.entries});

  final List<ActivityEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < entries.length; i++)
          _TimelineRow(entry: entries[i], isLast: i == entries.length - 1),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.entry, required this.isLast});

  final ActivityEntry entry;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: entry.color.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: AppIcon(
                    entry.iconName,
                    size: 20,
                    color: entry.color,
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 26,
                    margin: const EdgeInsets.only(top: 6),
                    color: AppColors.border,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: PressableScale(
              onTap: entry.matchId != null
                  ? () => context.push(AppRoutes.matchDetail(entry.matchId!))
                  : entry.itemId != null
                  ? () => context.push(AppRoutes.itemDetail(entry.itemId!))
                  : null,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.title,
                            style: AppText.bodyStrong.copyWith(fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          relativeTime(entry.at),
                          style: AppText.tiny.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.subtitle,
                            style: AppText.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (entry.matchId != null) ...[
                          const SizedBox(width: 6),
                          const AppIcon(
                            'alt-arrow-right-linear',
                            size: 14,
                            color: AppColors.textTertiary,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityEmpty extends StatelessWidget {
  const _ActivityEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const AppIcon(
              'clock-circle-linear',
              size: 26,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 12),
          Text('Aucune activité pour ce filtre', style: AppText.bodyStrong),
          const SizedBox(height: 4),
          Text(
            'Publiez une annonce ou vérifiez une correspondance.',
            style: AppText.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ActivitySkeleton extends StatelessWidget {
  const _ActivitySkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        4,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              const SkeletonCircle(size: 42),
              const SizedBox(width: 12),
              const Expanded(
                child: SkeletonBox(height: 62, borderRadius: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
