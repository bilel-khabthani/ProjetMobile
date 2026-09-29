import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_strings.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/item_match.dart';
import '../../data/providers.dart';
import '../../widgets/pressable_scale.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/status_pill.dart';
import 'widgets/match_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider);
    final matches = ref.watch(matchesProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => ref.invalidate(matchesProvider),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _Header(user: user)),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  child: _ActionRow(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  child: _SectionTitle(
                    title: AppStrings.sectionMatches,
                    subtitle: '',
                  ),
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
    final name = user?.name ?? '';
    final initials = user?.initials ?? 'LF';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_greeting()}${name.isEmpty ? '' : ' $name'}',
                  style: AppText.h1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Voici ce qui se passe sur votre campus.',
                  style: AppText.body,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Avatar(initials: initials, size: 48),
        ],
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
          child: _ActionCard(
            icon: Icons.search_off_rounded,
            title: AppStrings.actionLostTitle,
            subtitle: AppStrings.actionLostSubtitle,
            color: AppColors.lost,
            background: AppColors.lostSoft,
            onTap: () => context.push(AppRoutes.publish),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _ActionCard(
            icon: Icons.redeem_rounded,
            title: AppStrings.actionFoundTitle,
            subtitle: AppStrings.actionFoundSubtitle,
            color: AppColors.found,
            background: AppColors.foundSoft,
            onTap: () => context.push(AppRoutes.publish),
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: color.withValues(alpha: 0.22), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(title, style: AppText.h3.copyWith(fontSize: 16), maxLines: 2),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppText.caption.copyWith(height: 1.35),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.h2),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(subtitle, style: AppText.caption),
        ],
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
        itemCount: matches.length,
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
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.travel_explore_rounded,
              size: 40,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Aucune correspondance', style: AppText.h3),
            const SizedBox(height: 4),
            Text(
              'Publiez une annonce : notre moteur cherchera pour vous.',
              style: AppText.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: () => context.push(AppRoutes.publish),
              child: Text(
                'Publier une annonce',
                style: AppText.label.copyWith(color: AppColors.primary),
              ),
            ),
          ],
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
          3,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surface,
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        SkeletonBox(width: 170, height: 14),
                        SizedBox(height: 8),
                        SkeletonBox(width: 120, height: 11),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
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
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.danger),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Impossible de charger les correspondances.',
                style: AppText.body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivitySection extends StatelessWidget {
  const _ActivitySection({required this.matches});

  final List<ItemMatch> matches;

  @override
  Widget build(BuildContext context) {
    final items = [
      _ActivityItem(
        icon: Icons.published_with_changes_rounded,
        color: AppColors.lost,
        title: 'Annonce « Sac Nike noir » publiée',
        subtitle: 'Bloc A · hier à 10h30',
      ),
      if (matches.isNotEmpty)
        _ActivityItem(
          icon: Icons.auto_awesome_rounded,
          color: AppColors.primary,
          title:
              '${AppStrings.notifNewMatch} · ${matches.first.foundItemTitle}',
          subtitle:
              '${matches.first.scores.global.round()} % de correspondance',
        ),
      const _ActivityItem(
        icon: Icons.handshake_rounded,
        color: AppColors.found,
        title: '3 objets rendus à leurs propriétaires',
        subtitle: 'Réputation 4,8 ★',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: AppStrings.sectionActivity, subtitle: ''),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppShadows.card,
            ),
            child: Column(children: items),
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

  final IconData icon;
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
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.bodyStrong.copyWith(fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(subtitle, style: AppText.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
