import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/item_match.dart';
import '../../data/providers.dart';
import '../../widgets/app_icon.dart';
import '../home/widgets/match_card.dart';

class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = ref.watch(matchesProvider);

    return Scaffold(
      backgroundColor: context.colors.surface,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: context.colors.primary,
          onRefresh: () async => ref.invalidate(matchesProvider),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: _Header()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  child: _DiscoveryButton(
                    onTap: () => context.push(AppRoutes.swipe),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
              matches.when(
                loading: () => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    child: _ErrorState(
                      onRetry: () => ref.invalidate(matchesProvider),
                    ),
                  ),
                ),
                data: (items) => _MatchesList(matches: items),
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
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Correspondances', style: context.typography.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Examinez les objets que le moteur a rapprochés de vos annonces.',
            style: context.typography.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _DiscoveryButton extends StatelessWidget {
  const _DiscoveryButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Examiner les correspondances avec le moteur IA',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: context.colors.primaryContainer.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: context.colors.primary.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.colors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: AppIcon('stars-linear', color: context.colors.onPrimary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Examiner avec l’IA',
                      style: context.typography.bodyStrong,
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Glissez pour confirmer ou écarter chaque proposition.',
                      style: context.typography.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: context.colors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchesList extends StatelessWidget {
  const _MatchesList({required this.matches});

  final List<ItemMatch> matches;

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return const SliverToBoxAdapter(child: _EmptyState());
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: context.colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: context.colors.outlineVariant),
        ),
        child: Column(
          children: [
            AppIcon(
              'chat-round-dots-linear',
              size: 40,
              color: context.colors.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Aucune correspondance',
              style: context.typography.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Publiez une annonce pour lancer la recherche intelligente.',
              style: context.typography.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Impossible de charger les correspondances.',
            style: context.typography.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}
