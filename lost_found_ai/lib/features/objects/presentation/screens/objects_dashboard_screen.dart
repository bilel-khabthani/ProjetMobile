import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/item.dart';
import '../../../../widgets/app_icon.dart';
import '../../../../widgets/photo_placeholder.dart';
import '../../../../widgets/skeleton.dart';
import '../../data/providers/objects_providers.dart';

class ObjectsDashboardScreen extends ConsumerWidget {
  const ObjectsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(objectsStatsProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: context.colors.primary,
          onRefresh: () async {
            ref.invalidate(objectsStatsProvider);
            ref.invalidate(allObjectsProvider);
          },
          child: statsAsync.when(
            loading: () => const _LoadingState(),
            error: (error, _) => _ErrorState(
              error: error.toString(),
              onRetry: () => ref.invalidate(objectsStatsProvider),
            ),
            data: (stats) => _Content(stats: stats),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: context.colors.primary,
        foregroundColor: context.colors.onPrimary,
        onPressed: () => context.push(AppRoutes.objectAdd),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Signaler'),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.stats});

  final ObjectsStats stats;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.huge,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Objets perdus & trouvés',
                    style: context.typography.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs - 2),
                  Text(
                    'Gérez vos annonces et retrouvez vos objets.',
                    style: context.typography.bodyMedium,
                  ),
                ],
              ),
            ),
            Container(
              width: AppSpacing.huge + 8,
              height: AppSpacing.huge + 8,
              decoration: BoxDecoration(
                color: context.colors.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Center(
                child: AppIcon(
                  'magnifer-linear',
                  size: 26,
                  color: context.colors.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Perdus',
                value: stats.totalLostObjects.toString(),
                iconName: 'magnifer-linear',
                color: context.colors.primary,
                background: context.colors.primaryContainer,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatCard(
                title: 'Trouvés',
                value: stats.totalFoundObjects.toString(),
                iconName: 'hand-heart-linear',
                color: context.colors.secondary,
                background: context.colors.secondaryContainer,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Actifs',
                value: stats.activeAnnouncements.toString(),
                iconName: 'bolt-linear',
                color: context.colors.tertiary,
                background: context.colors.tertiaryContainer,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatCard(
                title: 'Récupérés',
                value: stats.recoveredAnnouncements.toString(),
                iconName: 'check-circle-bold',
                color: context.colors.primary,
                background: context.colors.secondaryContainer,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('Actions rapides', style: context.typography.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _QuickAction(
                label: 'Signaler\nperdu',
                iconName: 'magnifer-linear',
                color: context.colors.primary,
                background: context.colors.primaryContainer,
                onTap: () => context.push('${AppRoutes.objectAdd}?type=lost'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _QuickAction(
                label: 'Signaler\ntrouvé',
                iconName: 'hand-heart-linear',
                color: context.colors.secondary,
                background: context.colors.secondaryContainer,
                onTap: () => context.push('${AppRoutes.objectAdd}?type=found'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _QuickAction(
                label: 'Voir sur\nla carte',
                iconName: 'map-point-linear',
                color: context.colors.tertiary,
                background: context.colors.tertiaryContainer,
                onTap: () => context.push(AppRoutes.objectsMap),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Récemment publiés', style: context.typography.headlineSmall),
            TextButton(
              onPressed: () => context.push(AppRoutes.objectsList),
              child: const Text('Voir tous'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (stats.recentObjects.isEmpty)
          const _EmptyState()
        else
          ...stats.recentObjects.map(
            (object) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ObjectCard(object: object),
            ),
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.iconName,
    required this.color,
    required this.background,
  });

  final String title;
  final String value;
  final String iconName;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppSpacing.huge - 8,
            height: AppSpacing.huge - 8,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(AppSpacing.sm),
            ),
            child: Center(child: AppIcon(iconName, size: 20, color: color)),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            style: context.typography.headlineSmall?.copyWith(color: color),
          ),
          const SizedBox(height: 2),
          Text(title, style: context.typography.labelLarge),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.iconName,
    required this.color,
    required this.background,
    required this.onTap,
  });

  final String label;
  final String iconName;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppSpacing.huge - 12,
            height: AppSpacing.huge - 12,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(AppSpacing.sm),
            ),
            child: Center(child: AppIcon(iconName, size: 18, color: color)),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(label, style: context.typography.labelLarge, maxLines: 2),
        ],
      ),
    );
  }
}

class _ObjectCard extends StatelessWidget {
  const _ObjectCard({required this.object});

  final LostFoundObject object;

  @override
  Widget build(BuildContext context) {
    final isLost = object.type == ItemType.lost;
    final color = isLost ? context.colors.primary : context.colors.tertiary;
    final background = isLost
        ? context.colors.primaryContainer
        : context.colors.tertiaryContainer;

    return AppCard(
      onTap: () => context.push(AppRoutes.objectDetail(object.id)),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: AppSpacing.huge + 16,
            height: AppSpacing.huge + 16,
            child: object.imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                    child: Image.network(
                      object.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          ItemArtwork(category: object.category, compact: true),
                    ),
                  )
                : ItemArtwork(category: object.category, compact: true),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        object.title,
                        style: context.typography.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: background,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        object.type.shortLabel,
                        style: context.typography.labelSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    AppIcon(
                      'map-point-linear',
                      size: 13,
                      color: context.colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        object.placeLabel,
                        style: context.typography.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(object.formattedDate, style: context.typography.bodySmall),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          AppIcon(
            'box-linear',
            size: 40,
            color: context.colors.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Aucun objet signalé', style: context.typography.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Soyez le premier à signaler un objet perdu ou trouvé.',
            style: context.typography.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: () => context.push(AppRoutes.objectAdd),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Signaler un objet'),
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
        SkeletonBox(width: double.infinity, height: 64),
        SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(child: SkeletonBox(width: double.infinity, height: 110)),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: SkeletonBox(width: double.infinity, height: 110)),
          ],
        ),
        SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(child: SkeletonBox(width: double.infinity, height: 110)),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: SkeletonBox(width: double.infinity, height: 110)),
          ],
        ),
        SizedBox(height: AppSpacing.xl),
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
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.cloud_off_rounded, size: 48, color: context.colors.error),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Impossible de charger les objets',
          style: context.typography.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          error,
          style: context.typography.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: FilledButton(
            onPressed: onRetry,
            child: const Text('Réessayer'),
          ),
        ),
      ],
    );
  }
}
