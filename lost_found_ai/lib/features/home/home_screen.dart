import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_strings.dart';
import '../../core/router.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/item.dart';
import '../../data/models/item_match.dart';
import '../../data/providers.dart';
import '../../widgets/animated_count.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_reveal.dart';
import '../../widgets/hero_tags.dart';
import '../../widgets/app_section_header.dart';
import '../../widgets/app_state_view.dart';
import '../../widgets/photo_placeholder.dart';
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
    final hasData = matches.valueOrNull != null && myItems.valueOrNull != null;

    return Scaffold(
      backgroundColor: context.colors.surface,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: context.colors.primary,
          onRefresh: () async {
            ref.invalidate(matchesProvider);
            ref.invalidate(myItemsProvider);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _Reveal(
                  index: 0,
                  child: _Header(
                    user: user,
                    matchesCount: matches.valueOrNull?.length ?? 0,
                    itemsCount: myItems.valueOrNull?.length ?? 0,
                    hasData: hasData,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _Reveal(
                  index: 1,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                    child: _PrimaryActions(),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
              SliverToBoxAdapter(
                child: _Reveal(index: 2, child: const _QuickLinks()),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
              SliverToBoxAdapter(
                child: _Reveal(index: 3, child: const _MatchesHeader()),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
              SliverToBoxAdapter(
                child: AnimatedSwitcher(
                  duration: context.motion(AppMotion.short),
                  switchInCurve: AppMotion.enter,
                  switchOutCurve: AppMotion.exit,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.02),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: matches.when(
                    loading: () =>
                        const _MatchesLoading(key: ValueKey('matches-loading')),
                    error: (error, _) => _MatchesError(
                      key: const ValueKey('matches-error'),
                      onRetry: () => ref.invalidate(matchesProvider),
                    ),
                    data: (items) => _MatchesSection(
                      key: ValueKey('matches-${items.length}'),
                      matches: items,
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
              SliverToBoxAdapter(
                child: _Reveal(
                  index: 4,
                  child: _ActivitySection(
                    matches: matches.valueOrNull ?? const <ItemMatch>[],
                    myItems: myItems.valueOrNull ?? const <Item>[],
                  ),
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

class _Reveal extends StatelessWidget {
  const _Reveal({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      AppReveal(index: index, child: child);
}

class _Header extends StatelessWidget {
  const _Header({
    required this.user,
    required this.matchesCount,
    required this.itemsCount,
    required this.hasData,
  });

  final AppUser? user;
  final int matchesCount;
  final int itemsCount;
  final bool hasData;

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return AppStrings.homeGreetingMorning;
    if (hour < 18) return AppStrings.homeGreetingAfternoon;
    return AppStrings.homeGreetingEvening;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final name = user?.name ?? '';
    final initials = user?.initials ?? 'LF';

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primaryContainer.withValues(
              alpha: colors.isDark ? 0.5 : 0.78,
            ),
            colors.surface,
          ],
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.xl),
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _HeaderArtwork(
                  first: colors.primary.withValues(alpha: 0.08),
                  second: colors.tertiary.withValues(alpha: 0.08),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'VOTRE ESPACE',
                            style: AppText.eyebrow.copyWith(
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '${_greeting()}${name.isEmpty ? '' : ' $name'} 👋',
                            style: AppText.h1.copyWith(
                              fontSize: 27,
                              height: 1.18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.6,
                              color: colors.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Que voulez-vous faire aujourd’hui ?',
                            style: context.typography.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      decoration: BoxDecoration(
                        color: colors.surface.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: colors.outlineVariant),
                      ),
                      child: IconButton(
                        icon: AppIcon(
                          'gift-linear',
                          color: colors.primary,
                          size: 22,
                        ),
                        tooltip: 'Ouvrir mes récompenses',
                        onPressed: () => context.push(AppRoutes.rewards),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    PressableScale(
                      onTap: () => context.go(AppRoutes.profile),
                      child: Semantics(
                        button: true,
                        label: 'Ouvrir mon profil',
                        child: CircleAvatar(
                          radius: 25,
                          backgroundColor: colors.primary,
                          foregroundColor: colors.onPrimary,
                          child: Text(
                            initials,
                            style: context.typography.titleMedium?.copyWith(
                              color: colors.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _SummaryStrip(
                  matchesCount: matchesCount,
                  itemsCount: itemsCount,
                  hasData: hasData,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderArtwork extends CustomPainter {
  const _HeaderArtwork({required this.first, required this.second});

  final Color first;
  final Color second;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      Offset(size.width * 0.96, size.height * 0.06),
      size.shortestSide * 0.36,
      Paint()..color = first,
    );
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.9),
      size.shortestSide * 0.22,
      Paint()..color = second,
    );
  }

  @override
  bool shouldRepaint(covariant _HeaderArtwork old) =>
      old.first != first || old.second != second;
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.matchesCount,
    required this.itemsCount,
    required this.hasData,
  });

  final int matchesCount;
  final int itemsCount;
  final bool hasData;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryItem(
              icon: 'stars-linear',
              value: hasData ? '$matchesCount' : '—',
              label: 'Correspondances',
              color: colors.primary,
            ),
          ),
          Container(width: 1, height: 42, color: colors.outlineVariant),
          Expanded(
            child: _SummaryItem(
              icon: 'box-linear',
              value: hasData ? '$itemsCount' : '—',
              label: 'Annonces actives',
              color: colors.tertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final String icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
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
                value,
                style: context.typography.titleLarge?.copyWith(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: context.typography.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
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
    final colors = context.colors;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      color: background,
      borderRadius: AppRadius.xl,
      showBorder: false,
      child: SizedBox(
        height: 170,
        child: Stack(
          children: [
            Positioned(
              right: -34,
              bottom: -38,
              child: Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    boxShadow: AppShadows.primary,
                  ),
                  child: AppIcon(icon, color: colors.onPrimary, size: 26),
                ),
                const Spacer(),
                Text(
                  title,
                  style: context.typography.titleLarge?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle,
                  style: context.typography.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            Positioned(
              right: 0,
              top: 2,
              child: Icon(Icons.arrow_forward_rounded, size: 18, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickLinks extends StatelessWidget {
  const _QuickLinks();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: _QuickLinkItem(
                icon: 'stars-linear',
                label: 'Examiner',
                color: colors.primary,
                onTap: () => context.push(AppRoutes.swipe),
              ),
            ),
            Container(width: 1, height: 48, color: colors.outlineVariant),
            Expanded(
              child: _QuickLinkItem(
                icon: 'box-linear',
                label: 'Catalogue',
                color: colors.tertiary,
                onTap: () => context.go(AppRoutes.objects),
              ),
            ),
            Container(width: 1, height: 48, color: colors.outlineVariant),
            Expanded(
              child: _QuickLinkItem(
                icon: 'gift-linear',
                label: 'Récompenses',
                color: colors.secondary,
                onTap: () => context.push(AppRoutes.rewards),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickLinkItem extends StatelessWidget {
  const _QuickLinkItem({
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
    return Semantics(
      button: true,
      label: label,
      child: PressableScale(
        onTap: onTap,
        child: SizedBox(
          height: 74,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: AppIcon(icon, color: color, size: 19),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                label,
                style: context.typography.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
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
    return AppSectionHeader(
      title: AppStrings.sectionMatches,
      subtitle: 'Une sélection basée sur vos annonces',
      actionLabel: AppStrings.sectionSeeAll,
      onAction: () => context.go(AppRoutes.matches),
    );
  }
}

class _MatchesLoading extends StatelessWidget {
  const _MatchesLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recherche de correspondances…',
              style: context.typography.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            const SkeletonLoader(count: 2),
          ],
        ),
      ),
    );
  }
}

class _MatchesError extends StatelessWidget {
  const _MatchesError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: AppStateView(
        icon: Icons.cloud_off_rounded,
        title: 'Connexion indisponible',
        message: 'Impossible de charger les correspondances.',
        actionLabel: 'Réessayer',
        onAction: onRetry,
        tone: AppStateTone.error,
      ),
    );
  }
}

class _MatchesSection extends StatelessWidget {
  const _MatchesSection({super.key, required this.matches});

  final List<ItemMatch> matches;

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: AppStateView(
          icon: Icons.search_off_rounded,
          title: 'Aucune correspondance',
          message: 'Publiez une annonce : notre moteur cherchera pour vous.',
          actionLabel: 'Publier une annonce',
          onAction: () => context.push(AppRoutes.publish),
        ),
      );
    }

    final visible = matches.take(3).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        children: [
          _Reveal(
            index: 0,
            child: _FeaturedMatchCard(
              match: visible.first,
              onTap: () =>
                  context.push(AppRoutes.matchDetail(visible.first.id)),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _showScoreSheet(context),
              child: const Text('Comment est calculé ce score ?'),
            ),
          ),
          for (var index = 1; index < visible.length; index++) ...[
            if (index > 1) const SizedBox(height: AppSpacing.sm),
            _Reveal(
              index: index,
              child: MatchCard(
                match: visible[index],
                onTap: () =>
                    context.push(AppRoutes.matchDetail(visible[index].id)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

void _showScoreSheet(BuildContext context) {
  showAppBottomSheet<void>(
    context: context,
    semanticLabel: 'Explication du score de correspondance',
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xs,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comment est calculé ce score ?',
            style: sheetContext.typography.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Le score compare l’image, le lieu, le moment et la description de votre annonce avec l’objet trouvé. Un score élevé signifie que les indices se renforcent mutuellement.',
            style: sheetContext.typography.bodyMedium?.copyWith(
              color: sheetContext.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Compris',
            expand: false,
            onPressed: () => Navigator.of(sheetContext).pop(),
          ),
        ],
      ),
    ),
  );
}

class _FeaturedMatchCard extends StatelessWidget {
  const _FeaturedMatchCard({required this.match, required this.onTap});

  final ItemMatch match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final score = match.scores.global;
    final scoreColor = _scoreColor(score, colors);
    final onScoreColor = _onScoreColor(score, colors);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      borderRadius: AppRadius.xl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Hero(
                  tag: AppHeroTags.matchPhoto(match.id),

                child: Stack(
                  children: [
                    ItemArtwork(
                      category: match.foundItemCategory,
                      width: 132,
                      height: 132,
                      borderRadius: AppRadius.lg,
                      showLabel: true,
                    ),
                    Positioned(
                      right: AppSpacing.xs,
                      top: AppSpacing.xs,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs + 2,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: scoreColor,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          boxShadow: AppShadows.primary,
                        ),
                        child: AnimatedCount(
                          value: score,
                          format: (value) => '${value.round()}%',
                          style: AppText.score.copyWith(
                            fontSize: 18,
                            color: onScoreColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MEILLEURE CORRESPONDANCE',
                      style: AppText.eyebrow.copyWith(color: colors.primary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      match.foundItemTitle,
                      style: AppText.h1.copyWith(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      AppStrings.matchFoundAt(match.foundItemPlace),
                      style: context.typography.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 16,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            match.finderName,
                            style: context.typography.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                AppIcon('stars-linear', color: scoreColor, size: 18),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '${score.round()} % de correspondance',
                  style: context.typography.labelLarge?.copyWith(
                    color: colors.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  _matchAgo(match.minutesAgo),
                  style: context.typography.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _scoreColor(double score, ColorScheme scheme) => switch (score) {
  >= 80 => scheme.scoreHigh,
  >= 50 => scheme.scoreMedium,
  _ => scheme.scoreLow,
};

Color _onScoreColor(double score, ColorScheme scheme) => switch (score) {
  >= 80 => scheme.onScoreHigh,
  >= 50 => scheme.onScoreMedium,
  _ => scheme.onScoreLow,
};

String _matchAgo(int minutes) {
  if (minutes < 1) return AppStrings.justNow;
  if (minutes < 60) return AppStrings.minutesAgo(minutes);
  return AppStrings.hoursAgo(minutes ~/ 60);
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
        const _ActivityItem(
          icon: 'clock-circle-linear',
          color: null,
          title: 'Aucune activité récente',
          subtitle: 'Vos annonces et correspondances apparaîtront ici.',
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        children: [
          const AppSectionHeader(
            title: 'Activité récente',
            subtitle: 'Vos dernières annonces et correspondances',
          ),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
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
  final Color? color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? context.colors.textTertiary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: AppIcon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.typography.titleMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
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
