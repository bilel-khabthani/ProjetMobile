import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/router.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api_client.dart';
import '../../data/models/item.dart';
import '../../data/providers.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/status_pill.dart';

class ItemDetailScreen extends ConsumerWidget {
  const ItemDetailScreen({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync = ref.watch(itemProvider(itemId));
    return Scaffold(
      appBar: AppBar(
        title: Text('Détail', style: context.typography.titleLarge),
      ),
      body: itemAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  error is ApiException
                      ? error.userMessage
                      : 'Cette annonce est introuvable ou le serveur ne répond pas.',
                  style: context.typography.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: () => ref.invalidate(itemProvider(itemId)),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
        data: (item) => _DetailBody(item: item),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.item});

  final Item item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = item.occurredAt.toLocal();
    final dateLabel =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final accent = item.type == ItemType.lost
        ? context.colors.primary
        : context.colors.tertiary;
    final soft = item.type == ItemType.lost
        ? context.colors.primaryContainer
        : context.colors.tertiaryContainer;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.xl),
          child: SizedBox(
            height: 200,
            width: double.infinity,
            child: item.imageUrl == null
                ? ColoredBox(
                    color: soft,
                    child: Icon(
                      Icons.inventory_2_outlined,
                      size: 48,
                      color: accent,
                    ),
                  )
                : Image.network(
                    item.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => ColoredBox(
                      color: context.colors.surfaceContainerHighest,
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: 40,
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            StatusPill(type: item.type),
            const SizedBox(width: AppSpacing.xs),
            Text(item.status.label, style: context.typography.labelLarge),
          ],
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        Text(item.title, style: context.typography.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(item.description, style: context.typography.bodyMedium),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              _InfoRow(label: 'Catégorie', value: item.category.label),
              _InfoRow(label: 'Date', value: dateLabel),
              _InfoRow(
                label: 'Lieu',
                value: item.place.isEmpty ? 'Non précisé' : item.place,
              ),
              _InfoRow(
                label: 'Coordonnées',
                value: item.hasCoordinates
                    ? '${item.latitude!.toStringAsFixed(5)}, ${item.longitude!.toStringAsFixed(5)}'
                    : 'Non renseignées',
              ),
              _InfoRow(
                label: 'Contact',
                value: item.ownerName?.trim().isNotEmpty == true
                    ? item.ownerName!
                    : 'Membre du campus',
              ),
              if (item.isMine && (item.secretDetail?.isNotEmpty ?? false))
                _InfoRow(label: 'Détail secret', value: item.secretDetail!),
            ],
          ),
        ),
        if (item.isMine &&
            item.type == ItemType.lost &&
            (item.secretDetail?.trim().isEmpty ?? true)) ...[
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            color: context.colors.secondaryContainer,
            showBorder: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shield_outlined,
                  color: context.colors.onSecondaryContainer,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Détail secret manquant',
                        style: context.typography.titleMedium?.copyWith(
                          color: context.colors.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ajoutez un détail secret en modifiant cette annonce pour pouvoir vérifier une correspondance et débloquer le chat.',
                        style: context.typography.bodySmall?.copyWith(
                          color: context.colors.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (item.hasCoordinates) ...[
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.lg - 2),
            child: SizedBox(
              height: 160,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(item.latitude!, item.longitude!),
                  initialZoom: 15,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'fr.campus.lost_found_ai',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(item.latitude!, item.longitude!),
                        width: 36,
                        height: 36,
                        child: Icon(Icons.place, color: accent, size: 32),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        if (item.isMine) ...[
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Modifier',
            iconName: 'pen-linear',
            onPressed: () => context.push(AppRoutes.editItem(item.id)),
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'Supprimer',
            variant: AppButtonVariant.danger,
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      semanticLabel: 'Supprimer cette annonce',
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette annonce ?'),
        content: const Text(
          'Elle disparaîtra de la liste et de la carte. Cette action est définitive.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(repositoryProvider).deleteItem(item.id);
      ref.invalidate(myItemsProvider);
      ref.invalidate(catalogProvider);
      ref.invalidate(itemProvider);
      ref.invalidate(nearbyFoundProvider);
      ref.invalidate(matchesProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Annonce supprimée.')));
      context.pop();
    } on ApiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.userMessage)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Suppression impossible. Réessayez.')),
      );
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: context.typography.labelLarge?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: context.typography.bodyMedium)),
        ],
      ),
    );
  }
}
