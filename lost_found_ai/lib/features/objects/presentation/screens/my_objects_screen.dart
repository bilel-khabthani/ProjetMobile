import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/item.dart';
import '../../../../widgets/photo_placeholder.dart';
import '../../../../widgets/skeleton.dart';
import '../../data/providers/objects_providers.dart';

enum _MyFilter { all, active, recovered }

class MyObjectsScreen extends ConsumerStatefulWidget {
  const MyObjectsScreen({super.key});

  @override
  ConsumerState<MyObjectsScreen> createState() => _MyObjectsScreenState();
}

class _MyObjectsScreenState extends ConsumerState<MyObjectsScreen> {
  _MyFilter _filter = _MyFilter.all;

  List<LostFoundObject> _apply(List<LostFoundObject> objects) {
    return switch (_filter) {
      _MyFilter.all => objects,
      _MyFilter.active =>
        objects.where((o) => o.status == ItemStatus.active).toList(),
      _MyFilter.recovered =>
        objects.where((o) => o.status != ItemStatus.active).toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(myObjectsStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Mes annonces', style: context.typography.titleLarge),
      ),
      body: statsAsync.when(
        loading: () => const _LoadingState(),
        error: (error, _) => _ErrorState(
          error: error.toString(),
          onRetry: () => ref.invalidate(myObjectsStatsProvider),
        ),
        data: (stats) {
          final objects = _apply(stats.allObjects);
          return RefreshIndicator(
            color: context.colors.primary,
            onRefresh: () async {
              ref.invalidate(myObjectsStatsProvider);
              await ref.read(myObjectsStatsProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xs,
                AppSpacing.xl,
                AppSpacing.xxxl,
              ),
              children: [
                _StatsRow(stats: stats),
                const SizedBox(height: AppSpacing.lg),
                _FilterBar(
                  filter: _filter,
                  onChanged: (value) => setState(() => _filter = value),
                ),
                const SizedBox(height: AppSpacing.md),
                if (objects.isEmpty)
                  _EmptyState(filter: _filter)
                else
                  for (final object in objects) ...[
                    _MyObjectTile(
                      object: object,
                      onTap: () =>
                          context.push(AppRoutes.objectDetail(object.id)),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: context.colors.primary,
        foregroundColor: context.colors.onPrimary,
        onPressed: () => context.push(AppRoutes.objectAdd),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Publier'),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final MyObjectsStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniStat(
            label: 'Actives',
            value: '${stats.myActiveObjects}',
            color: context.colors.primary,
            soft: context.colors.primaryContainer,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _MiniStat(
            label: 'Récupérées',
            value: '${stats.myRecoveredObjects}',
            color: context.colors.secondary,
            soft: context.colors.secondaryContainer,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _MiniStat(
            label: 'Total',
            value: '${stats.totalObjects}',
            color: context.colors.tertiary,
            soft: context.colors.tertiaryContainer,
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
    required this.soft,
  });

  final String label;
  final String value;
  final Color color;
  final Color soft;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: soft,
      showBorder: false,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: context.typography.headlineSmall?.copyWith(color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: context.typography.labelLarge?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.filter, required this.onChanged});

  final _MyFilter filter;
  final ValueChanged<_MyFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<_MyFilter>(
        segments: const [
          ButtonSegment<_MyFilter>(value: _MyFilter.all, label: Text('Tout')),
          ButtonSegment<_MyFilter>(
            value: _MyFilter.active,
            label: Text('Actives'),
          ),
          ButtonSegment<_MyFilter>(
            value: _MyFilter.recovered,
            label: Text('Récupérées'),
          ),
        ],
        selected: {filter},
        showSelectedIcon: false,
        multiSelectionEnabled: false,
        style: SegmentedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
        ),
        onSelectionChanged: (selection) => onChanged(selection.first),
      ),
    );
  }
}

class _MyObjectTile extends StatelessWidget {
  const _MyObjectTile({required this.object, required this.onTap});

  final LostFoundObject object;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLost = object.type == ItemType.lost;
    final color = isLost ? context.colors.primary : context.colors.tertiary;
    final soft = isLost
        ? context.colors.primaryContainer
        : context.colors.tertiaryContainer;
    final recovered = object.status != ItemStatus.active;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.sm),
            child: SizedBox(
              width: AppSpacing.huge + 16,
              height: AppSpacing.huge + 16,
              child: object.imageUrl != null
                  ? Image.network(
                      object.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          ItemArtwork(category: object.category),
                    )
                  : ItemArtwork(category: object.category),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  object.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  '${object.category.label} · ${object.formattedDate}',
                  style: context.typography.bodySmall,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _Dot(
                      color: color,
                      soft: soft,
                      label: object.type.shortLabel,
                    ),
                    const SizedBox(width: 6),
                    _Dot(
                      color: recovered
                          ? context.colors.tertiary
                          : context.colors.onSurfaceVariant,
                      soft: recovered
                          ? context.colors.tertiaryContainer
                          : context.colors.surfaceContainerHigh,
                      label: recovered ? 'RÉCUPÉRÉ' : 'EN COURS',
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: context.colors.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.soft, required this.label});

  final Color color;
  final Color soft;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: context.typography.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});

  final _MyFilter filter;

  @override
  Widget build(BuildContext context) {
    final message = switch (filter) {
      _MyFilter.all => 'Tu n\'as encore publié aucune annonce.',
      _MyFilter.active => 'Aucune annonce active.',
      _MyFilter.recovered => 'Aucun objet récupéré pour le moment.',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.huge),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 52,
            color: context.colors.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            style: context.typography.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: const [
        SkeletonBox(width: double.infinity, height: 84),
        SizedBox(height: AppSpacing.lg),
        SkeletonBox(width: double.infinity, height: 36),
        SizedBox(height: AppSpacing.md),
        SkeletonBox(width: double.infinity, height: 88),
        SizedBox(height: AppSpacing.sm),
        SkeletonBox(width: double.infinity, height: 88),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: context.colors.error,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Impossible de charger tes annonces',
              style: context.typography.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              error,
              style: context.typography.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
