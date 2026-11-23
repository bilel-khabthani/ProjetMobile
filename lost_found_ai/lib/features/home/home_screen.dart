import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_strings.dart';
import '../../core/router.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/item.dart';
import '../../data/models/item_match.dart';
import '../../data/providers.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/pressable_scale.dart';
import '../../widgets/skeleton.dart';
import 'widgets/match_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider);
    final matches = ref.watch(matchesProvider);
    final myItems = ref.watch(myItemsProvider);
    final scheme = context.colors;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: scheme.primary,
          onRefresh: () async {
            ref.invalidate(matchesProvider);
            ref.invalidate(myItemsProvider);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _Header(user: user)),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  child: _PrimaryActions(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  child: _QuickLinks(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  child: _MatchesHeader(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
              matches.when(
                loading: () =>
                    const SliverToBoxAdapter(child: _MatchesSkeleton()),
                error: (error, _) =>
                    const SliverToBoxAdapter(child: _MatchesError()),
                data: (items) => _MatchesSection(matches: items),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
              SliverToBoxAdapter(
                child: _ActivitySection(
                  matches: matches.valueOrNull ?? const <ItemMatch>[],
                  myItems: myItems.valueOrNull ?? const <Item>[],
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.user});

  final AppUser? user;

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return AppStrings.homeGreetingMorning;
    if (hour < 18) return AppStrings.homeGreetingAfternoon;
    return AppStrings.homeGreetingEvening;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final textTheme = context.typography;
    final name = user?.name ?? '';
    final initials = user?.initials ?? 'LF';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_greeting()}${name.isEmpty ? '' : ' $name'}',
                  style: textTheme.headlineMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Que voulez-vous faire aujourd’hui ?',
                  style: textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Semantics(
            button: true,
            label: 'Ouvrir mes récompenses',
            child: IconButton(
              icon: AppIcon('gift-linear', color: scheme.tertiary),
              onPressed: () => context.push(AppRoutes.rewards),
              tooltip: 'Récompenses & Coupons',
            ),
          ),
          Semantics(
            button: true,
            label: 'Ouvrir mon profil',
            child: PressableScale(
              onTap: () => context.go(AppRoutes.profile),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.onPrimaryContainer,
                child: Text(initials, style: textTheme.titleMedium),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryActions extends StatelessWidget {
  const _PrimaryActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PrimaryActionCard(
            icon: 'magnifer-linear',
            title: AppStrings.actionLostTitle,
            subtitle: AppStrings.actionLostSubtitle,
            color: context.colors.primary,
            background: context.colors.primaryContainer,
            onTap: () => context.push('${AppRoutes.publish}?type=lost'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _PrimaryActionCard(
            icon: 'box-linear',
            title: AppStrings.actionFoundTitle,
            subtitle: AppStrings.actionFoundSubtitle,
            color: context.colors.tertiary,
            background: context.colors.tertiaryContainer,
            onTap: () => context.push('${AppRoutes.publish}?type=found'),
          ),
        ),
      ],
    );
  }
}

class _PrimaryActionCard extends StatelessWidget {
  const _PrimaryActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.background,
    required this.onTap,
  });

  final String icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.typography;
    return Semantics(
      button: true,
      label: title,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.md),
        color: background,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 124),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: AppIcon(icon, color: context.colors.onPrimary, size: 24),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(title, style: textTheme.titleMedium, maxLines: 2),
              const SizedBox(height: 2),
              Text(subtitle, style: textTheme.bodySmall, maxLines: 3),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickLinks extends StatelessWidget {
  const _QuickLinks();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickLink(
            icon: 'stars-linear',
            label: 'Examiner',
            color: context.colors.primary,
            onTap: () => context.push(AppRoutes.swipe),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _QuickLink(
            icon: 'box-linear',
            label: 'Catalogue',
            color: context.colors.tertiary,
            onTap: () => context.go(AppRoutes.objects),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _QuickLink(
            icon: 'gift-linear',
            label: 'Récompenses',
            color: context.colors.secondary,
            onTap: () => context.push(AppRoutes.rewards),
          ),
        ),
      ],
    );
  }
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.typography;
    return Semantics(
      button: true,
      label: label,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.sm,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(icon, color: color, size: 20),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                label,
                style: textTheme.labelMedium?.copyWith(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchesHeader extends StatelessWidget {
  const _MatchesHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            AppStrings.sectionMatches,
            style: context.typography.headlineSmall,
          ),
        ),
        TextButton(
          onPressed: () => context.go(AppRoutes.matches),
          child: Text(AppStrings.sectionSeeAll),
        ),
      ],
    );
  }
}

class _MatchesSection extends StatelessWidget {
  const _MatchesSection({required this.matches});

  final List<ItemMatch> matches;

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return const SliverToBoxAdapter(child: _EmptyMatches());
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      sliver: SliverList.separated(
        itemCount: matches.take(3).length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final match = matches[index];
          return MatchCard(
            match: match,
            onTap: () => context.push(AppRoutes.matchDetail(match.id)),
          );
        },
      ),
    );
  }
}

class _EmptyMatches extends StatelessWidget {
  const _EmptyMatches();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        0,
      ),
      child: Semantics(
        container: true,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(),
          child: Column(
            children: [
              AppIcon(
                'chat-round-dots-linear',
                size: 40,
                color: context.colors.textTertiary,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('Aucune correspondance', style: context.typography.h3),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Publiez une annonce : notre moteur cherchera pour vous.',
                style: context.typography.caption,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () => context.push(AppRoutes.publish),
                child: Text('Publier une annonce'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchesSkeleton extends StatelessWidget {
  const _MatchesSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        children: List.generate(
          2,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: context.colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(
                children: [
                  const SkeletonBox(
                    width: 68,
                    height: 68,
                    borderRadius: AppRadius.md,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 170, height: 14),
                        SizedBox(height: 8),
                        SkeletonBox(width: 120, height: 11),
                      ],
                    ),
                  ),
                  const SkeletonBox(width: 52, height: 52, borderRadius: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MatchesError extends StatelessWidget {
  const _MatchesError();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Icon(Icons.cloud_off_rounded, color: context.colors.error),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Impossible de charger les correspondances.',
                style: context.typography.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivitySection extends StatelessWidget {
  const _ActivitySection({required this.matches, required this.myItems});

  final List<ItemMatch> matches;
  final List<Item> myItems;

  @override
  Widget build(BuildContext context) {
    final entries = <_ActivityItem>[
      for (final item in myItems.take(2))
        _ActivityItem(
          icon: 'box-linear',
          color: item.type == ItemType.lost
              ? context.colors.lost
              : context.colors.found,
          title: 'Annonce « ${item.title} » publiée',
          subtitle:
              '${item.place.isEmpty ? item.category.label : item.place} · ${_relativeTime(item.occurredAt)}',
        ),
      for (final match in matches.take(2))
        _ActivityItem(
          icon: 'stars-linear',
          color: context.colors.primary,
          title: 'Nouvelle correspondance · ${match.foundItemTitle}',
          subtitle: '${match.scores.global.round()} % de correspondance',
        ),
    ];

    if (entries.isEmpty) {
      entries.add(
        _ActivityItem(
          icon: 'clock-circle-linear',
          color: context.colors.textTertiary,
          title: 'Aucune activité récente',
          subtitle: 'Vos annonces et correspondances apparaîtront ici.',
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Activité récente', style: context.typography.h2),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: Column(children: entries.take(4).toList()),
          ),
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  const _ActivityItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final String icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: AppIcon(icon, color: color, size: 19),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.typography.titleMedium?.copyWith(fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(subtitle, style: context.typography.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'à l’instant';
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
  if (diff.inDays == 1) return 'hier';
  if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
  final day = dt.day.toString().padLeft(2, '0');
  final month = dt.month.toString().padLeft(2, '0');
  return '$day/$month/${dt.year}';
}
