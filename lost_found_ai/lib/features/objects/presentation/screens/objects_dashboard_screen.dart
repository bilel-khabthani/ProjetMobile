import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../data/models/item.dart';
import '../../../../widgets/app_icon.dart';
import '../../../../widgets/photo_placeholder.dart';
import '../../../../widgets/pressable_scale.dart';
import '../../../../widgets/skeleton.dart';
import '../../data/providers/objects_providers.dart';

class ObjectsDashboardScreen extends ConsumerWidget {
  const ObjectsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(objectsStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
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
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
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
                  Text('Objets perdus & trouvés', style: AppText.h1),
                  const SizedBox(height: 6),
                  Text(
                    'Gérez vos annonces et retrouvez vos objets.',
                    style: AppText.body,
                  ),
                ],
              ),
            ),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Center(
                child: AppIcon('magnifer-linear', size: 26, color: AppColors.primary),
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
                color: AppColors.lost,
                background: AppColors.lostSoft,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatCard(
                title: 'Trouvés',
                value: stats.totalFoundObjects.toString(),
                iconName: 'hand-heart-linear',
                color: AppColors.found,
                background: AppColors.foundSoft,
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
                color: AppColors.primary,
                background: AppColors.primarySoft,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatCard(
                title: 'Récupérés',
                value: stats.recoveredAnnouncements.toString(),
                iconName: 'check-circle-bold',
                color: AppColors.success,
                background: AppColors.mint,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('Actions rapides', style: AppText.h2),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _QuickAction(
                label: 'Signaler\nperdu',
                iconName: 'magnifer-linear',
                color: AppColors.lost,
                background: AppColors.lostSoft,
                onTap: () =>
                    context.push('${AppRoutes.objectAdd}?type=lost'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _QuickAction(
                label: 'Signaler\ntrouvé',
                iconName: 'hand-heart-linear',
                color: AppColors.found,
                background: AppColors.foundSoft,
                onTap: () =>
                    context.push('${AppRoutes.objectAdd}?type=found'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _QuickAction(
                label: 'Voir sur\nla carte',
                iconName: 'map-point-linear',
                color: AppColors.accent,
                background: AppColors.accentSoft,
                onTap: () => context.push(AppRoutes.objectsMap),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Récemment publiés', style: AppText.h2),
            PressableScale(
              onTap: () => context.push(AppRoutes.objectsList),
              child: Text(
                'Voir tous',
                style: AppText.label.copyWith(color: AppColors.primary),
              ),
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Center(child: AppIcon(iconName, size: 20, color: Colors.white)),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(value, style: AppText.score),
          const SizedBox(height: 2),
          Text(title, style: AppText.label),
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
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Center(
                child: AppIcon(iconName, size: 18, color: Colors.white),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: AppText.label.copyWith(fontSize: 12),
              maxLines: 2,
            ),
          ],
        ),
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
    final color = isLost ? AppColors.lost : AppColors.found;
    final background = isLost ? AppColors.lostSoft : AppColors.foundSoft;

    return PressableScale(
      onTap: () => context.push(AppRoutes.objectDetail(object.id)),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: object.imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
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
                          style: AppText.bodyStrong,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: background,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          object.type.shortLabel,
                          style: AppText.tiny.copyWith(
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
                      AppIcon('map-point-linear',
                          size: 13, color: AppColors.textTertiary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          object.placeLabel,
                          style: AppText.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    object.formattedDate,
                    style: AppText.caption.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const AppIcon('box-linear', size: 40, color: AppColors.textTertiary),
          const SizedBox(height: AppSpacing.sm),
          Text('Aucun objet signalé', style: AppText.h3),
          const SizedBox(height: 4),
          Text(
            'Soyez le premier à signaler un objet perdu ou trouvé.',
            style: AppText.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
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
        const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.danger),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Impossible de charger les objets',
          style: AppText.h2,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(error, style: AppText.body, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: onRetry,
            child: const Text('Réessayer'),
          ),
        ),
      ],
    );
  }
}
