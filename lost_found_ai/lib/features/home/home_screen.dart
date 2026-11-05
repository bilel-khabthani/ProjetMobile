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
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/pressable_scale.dart';
import '../../widgets/score_gauge.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/status_pill.dart';
import '../activity/activity_feed.dart';
import 'widgets/match_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider);
    final matches = ref.watch(matchesProvider);
    final myItems = ref.watch(myItemsProvider);
    final trust = ref.watch(trustProvider);
    final nearby = ref.watch(nearbyFoundProvider);

    Future<void> refresh() async {
      ref.invalidate(matchesProvider);
      ref.invalidate(myItemsProvider);
      ref.invalidate(trustProvider);
      ref.invalidate(nearbyFoundProvider);
      try {
        await Future.wait([
          ref.read(matchesProvider.future),
          ref.read(myItemsProvider.future),
          ref.read(nearbyFoundProvider.future),
        ]);
      } catch (_) {
        // Le bandeau d'erreur de chaque section prend le relais.
      }
    }

    final matchList = matches.valueOrNull ?? const <ItemMatch>[];
    final itemList = myItems.valueOrNull ?? const <Item>[];
    final feed = buildActivityFeed(matches: matchList, myItems: itemList);

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const AppBottomNav(active: AppTab.home),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: _Header(
                  user: user,
                  hasMatches: matchList.isNotEmpty,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                  child: _TrustCard(
                    score: trust.valueOrNull?.score ?? user?.reputation ?? 0,
                    recovered: trust.valueOrNull?.recoveredCount ??
                        user?.recoveredCount ??
                        0,
                    canChat: trust.valueOrNull?.canChat ?? true,
                    onTap: () => context.push(AppRoutes.trust),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: _ActionRow(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
              SliverToBoxAdapter(
                child: _SectionHeader(
                  title: AppStrings.sectionMatches,
                  subtitle: AppStrings.matchesSubtitle(matchList.length),
                  trailing: AppStrings.sectionSeeAll,
                  onTrailingTap: () => context.go(AppRoutes.messages),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 266,
                  child: matches.when(
                    loading: () => const _SpotlightSkeleton(),
                    error: (_, _) => const _ErrorCard(
                      message: 'Impossible de charger les correspondances.',
                    ),
                    data: (items) => items.isEmpty
                        ? const _MatchesEmpty()
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            physics: const BouncingScrollPhysics(),
                            itemCount: items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final match = items[index];
                              return MatchSpotlightCard(
                                match: match,
                                onTap: () => context.push(
                                  AppRoutes.matchDetail(match.id),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 26)),
              SliverToBoxAdapter(
                child: _SectionHeader(
                  title: AppStrings.homeNearbyTitle,
                  subtitle: 'Suggestions du moteur autour de vous',
                  trailing: AppStrings.sectionSeeAll,
                  onTrailingTap: () => context.go(AppRoutes.explore),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: nearby.when(
                    loading: () => const _NearbySkeleton(),
                    error: (_, _) => _NearbyEmpty(
                      hasLostItem: itemList.any(
                        (item) => item.type == ItemType.lost,
                      ),
                    ),
                    data: (data) {
                      final items = data
                          .map(NearbyFound.fromJson)
                          .toList(growable: false);
                      if (items.isEmpty) {
                        return _NearbyEmpty(
                          hasLostItem: itemList.any(
                            (item) => item.type == ItemType.lost,
                          ),
                        );
                      }
                      return Column(
                        children: [
                          for (var i = 0; i < items.take(3).length; i++) ...[
                            if (i > 0) const SizedBox(height: 10),
                            Builder(
                              builder: (context) {
                                final item = items[i];
                                String? matchId;
                                for (final match in matchList) {
                                  if (match.foundItemTitle.toLowerCase() ==
                                      item.title.toLowerCase()) {
                                    matchId = match.id;
                                    break;
                                  }
                                }
                                return NearbyFoundTile(
                                  item: item,
                                  onTap: () => showNearbyFoundSheet(
                                    context,
                                    item,
                                    matchId: matchId,
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 26)),
              SliverToBoxAdapter(
                child: _SectionHeader(
                  title: AppStrings.sectionActivity,
                  subtitle: 'Vos derniers mouvements',
                  trailing: AppStrings.sectionSeeAll,
                  onTrailingTap: () => context.push(AppRoutes.activity),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: feed.isEmpty
                      ? const _ActivityEmpty()
                      : _ActivityPreview(entries: feed.take(3).toList()),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.user, required this.hasMatches});

  final AppUser? user;
  final bool hasMatches;

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return AppStrings.homeGreetingMorning;
    if (hour < 18) return AppStrings.homeGreetingAfternoon;
    return AppStrings.homeGreetingEvening;
  }

  @override
  Widget build(BuildContext context) {
    final name = user?.name.trim() ?? '';
    final firstName = name.isEmpty ? '' : name.split(RegExp(r'\s+')).first;
    final greeting = '${_greeting()}${firstName.isEmpty ? '' : ', $firstName'}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CAMPUS · LOST & FOUND',
                  style: AppText.eyebrow.copyWith(color: AppColors.primary),
                ),
                const SizedBox(height: 6),
                Text(
                  greeting,
                  style: AppText.h1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  'Voici ce qui se passe autour de vous.',
                  style: AppText.body.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _CircleButton(
            icon: 'bell-linear',
            onTap: () => context.push(AppRoutes.activity),
            showDot: hasMatches,
          ),
          const SizedBox(width: 8),
          PressableScale(
            onTap: () => context.go(AppRoutes.profile),
            child: Avatar(initials: user?.initials ?? 'LF', size: 46),
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.showDot = false,
  });

  final String icon;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.divider),
          boxShadow: AppShadows.card,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AppIcon(icon, size: 21, color: AppColors.textPrimary),
            if (showDot)
              Positioned(
                top: 12,
                right: 13,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.lost,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TrustCard extends StatelessWidget {
  const _TrustCard({
    required this.score,
    required this.recovered,
    required this.canChat,
    required this.onTap,
  });

  final double score;
  final int recovered;
  final bool canChat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = score >= 70
        ? AppColors.found
        : score >= 40
        ? AppColors.accent
        : AppColors.lost;

    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF0EDFF), AppColors.surface],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.16),
          ),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            ScoreGauge(
              value: score,
              size: 58,
              strokeWidth: 6,
              color: color,
              secondaryColor: color.withValues(alpha: 0.45),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.homeTrustTitle,
                    style: AppText.bodyStrong,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$recovered restitution${recovered > 1 ? 's' : ''} · '
                    '${canChat ? 'messagerie active' : 'messagerie en attente'}',
                    style: AppText.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: const AppIcon(
                'alt-arrow-right-linear',
                size: 17,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _HeroAction(
            icon: 'magnifer-linear',
            title: AppStrings.actionLostTitle,
            subtitle: AppStrings.actionLostSubtitle,
            foreground: Colors.white,
            background: AppColors.lost,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF5836F), Color(0xFFE45C4A)],
            ),
            onTap: () => context.push('${AppRoutes.publish}?type=lost'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _HeroAction(
            icon: 'hand-heart-linear',
            title: AppStrings.actionFoundTitle,
            subtitle: AppStrings.actionFoundSubtitle,
            foreground: AppColors.mintDark,
            background: AppColors.foundSoft,
            border: AppColors.found.withValues(alpha: 0.24),
            onTap: () => context.push('${AppRoutes.publish}?type=found'),
          ),
        ),
      ],
    );
  }
}

class _HeroAction extends StatelessWidget {
  const _HeroAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.foreground,
    required this.background,
    required this.onTap,
    this.gradient,
    this.border,
  });

  final String icon;
  final String title;
  final String subtitle;
  final Color foreground;
  final Color background;
  final VoidCallback onTap;
  final Gradient? gradient;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final solid = gradient != null;

    return PressableScale(
      onTap: onTap,
      child: Container(
        height: 176,
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: gradient == null ? background : null,
          gradient: gradient,
          borderRadius: BorderRadius.circular(26),
          border: border == null ? null : Border.all(color: border!),
          boxShadow: solid ? AppShadows.raised : null,
        ),
        child: Stack(
          children: [
            Positioned(
              right: -26,
              top: -30,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: solid
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              right: 14,
              bottom: -22,
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: solid
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: solid ? Colors.white.withValues(alpha: 0.2) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: AppIcon(icon, size: 22, color: foreground),
                ),
                const Spacer(),
                Text(
                  title,
                  style: AppText.h3.copyWith(
                    color: foreground,
                    fontSize: 16,
                    height: 1.15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: AppText.tiny.copyWith(
                    color: solid
                        ? Colors.white.withValues(alpha: 0.82)
                        : foreground.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTrailingTap,
  });

  final String title;
  final String subtitle;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.h2),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: AppText.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTrailingTap,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 2),
                child: Row(
                  children: [
                    Text(
                      trailing!,
                      style: AppText.label.copyWith(color: AppColors.primary),
                    ),
                    const SizedBox(width: 3),
                    const AppIcon(
                      'alt-arrow-right-linear',
                      size: 15,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MatchesEmpty extends StatelessWidget {
  const _MatchesEmpty();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const AppIcon(
                  'link-round-linear',
                  size: 26,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Aucune correspondance', style: AppText.bodyStrong),
                    const SizedBox(height: 3),
                    Text(
                      'Publiez une annonce : le moteur cherchera pour vous.',
                      style: AppText.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () =>
                          context.push('${AppRoutes.publish}?type=lost'),
                      child: Text(
                        'Publier une annonce',
                        style: AppText.label.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
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

class _SpotlightSkeleton extends StatelessWidget {
  const _SpotlightSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: 2,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (_, _) => Container(
        width: 276,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.divider),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(height: 126, borderRadius: 18),
            SizedBox(height: 14),
            SkeletonBox(width: 180, height: 15),
            SizedBox(height: 8),
            SkeletonBox(width: 130, height: 11),
            SizedBox(height: 12),
            SkeletonBox(width: 150, height: 11),
          ],
        ),
      ),
    );
  }
}

class _NearbySkeleton extends StatelessWidget {
  const _NearbySkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        2,
        (index) => Padding(
          padding: EdgeInsets.only(bottom: index == 0 ? 10 : 0),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.divider),
            ),
            child: const Row(
              children: [
                SkeletonBox(width: 60, height: 60, borderRadius: 16),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 160, height: 13),
                      SizedBox(height: 8),
                      SkeletonBox(width: 110, height: 10),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NearbyEmpty extends StatelessWidget {
  const _NearbyEmpty({required this.hasLostItem});

  final bool hasLostItem;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.foundSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.found.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const AppIcon(
              'hand-heart-linear',
              size: 23,
              color: AppColors.mintDark,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasLostItem
                      ? 'Aucune suggestion pour l’instant'
                      : 'Activez les suggestions',
                  style: AppText.bodyStrong.copyWith(
                    color: AppColors.mintDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hasLostItem
                      ? 'Notre moteur analyse les objets trouvés en continu.'
                      : 'Publiez une annonce perdue pour voir les objets trouvés.',
                  style: AppText.caption.copyWith(
                    color: AppColors.mintDark.withValues(alpha: 0.75),
                  ),
                ),
                if (!hasLostItem) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () =>
                        context.push('${AppRoutes.publish}?type=lost'),
                    child: Text(
                      'Publier une annonce',
                      style: AppText.label.copyWith(color: AppColors.mintDark),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityPreview extends StatelessWidget {
  const _ActivityPreview({required this.entries});

  final List<ActivityEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, indent: 58, endIndent: 10),
            PressableScale(
              onTap: entries[i].matchId == null
                  ? null
                  : () => context.push(
                      AppRoutes.matchDetail(entries[i].matchId!),
                    ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: entries[i].color.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: AppIcon(
                        entries[i].iconName,
                        size: 19,
                        color: entries[i].color,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entries[i].title,
                            style: AppText.bodyStrong.copyWith(fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            entries[i].subtitle,
                            style: AppText.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      relativeTime(entries[i].at),
                      style: AppText.tiny.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          const AppIcon(
            'clock-circle-linear',
            size: 22,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Vos annonces et correspondances apparaîtront ici.',
              style: AppText.caption,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const AppIcon(
                'danger-triangle-linear',
                size: 22,
                color: AppColors.danger,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(message, style: AppText.body)),
            ],
          ),
        ),
      ),
    );
  }
}
