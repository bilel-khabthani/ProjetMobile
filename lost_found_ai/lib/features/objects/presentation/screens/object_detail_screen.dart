import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/item.dart';
import '../../../../data/providers.dart';
import '../../../../widgets/app_button.dart';
import '../../../../widgets/app_icon.dart';
import '../../../../widgets/photo_placeholder.dart';
import '../../../../widgets/skeleton.dart';
import '../../data/providers/objects_providers.dart';

class ObjectDetailScreen extends ConsumerWidget {
  const ObjectDetailScreen({required this.objectId, super.key});

  final String objectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final objectAsync = ref.watch(objectDetailProvider(objectId));
    final user = ref.watch(sessionProvider);

    return Scaffold(
      appBar: AppBar(
        actions: [
          objectAsync.maybeWhen(
            data: (object) => user != null && object.canEdit(user.id)
                ? IconButton(
                    tooltip: 'Modifier',
                    icon: const Icon(Icons.edit_rounded),
                    onPressed: () =>
                        context.push(AppRoutes.objectEdit(object.id)),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: objectAsync.when(
        loading: () => const _LoadingState(),
        error: (error, _) => _ErrorState(
          error: error.toString(),
          onRetry: () => ref.invalidate(objectDetailProvider(objectId)),
        ),
        data: (object) => _Content(object: object, currentUserId: user?.id),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.object, required this.currentUserId});

  final LostFoundObject object;
  final String? currentUserId;

  bool get _isOwner =>
      currentUserId != null && object.isOwnedBy(currentUserId!);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLost = object.type == ItemType.lost;
    final color = isLost ? context.colors.primary : context.colors.tertiary;
    final background = isLost
        ? context.colors.primaryContainer
        : context.colors.tertiaryContainer;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _Hero(object: object, color: color, background: background),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      object.title,
                      style: context.typography.headlineMedium,
                    ),
                  ),
                  _StatusBadge(object: object),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppIcon(
                          categoryIconName(object.category),
                          size: 14,
                          color: color,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          object.category.label,
                          style: context.typography.labelSmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    object.formattedDate,
                    style: context.typography.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(object.description, style: context.typography.bodyMedium),
              const SizedBox(height: AppSpacing.xl),
              _InfoTile(
                iconName: 'map-point-linear',
                title: 'Localisation',
                subtitle: object.placeLabel.isEmpty
                    ? 'Non renseignée'
                    : object.placeLabel,
                trailing: object.latitude != null && object.longitude != null
                    ? TextButton(
                        onPressed: () => context.push(AppRoutes.objectsMap),
                        child: const Text('Voir'),
                      )
                    : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              _InfoTile(
                iconName: 'calendar-linear',
                title: 'Date',
                subtitle:
                    '${object.occurredAt.day.toString().padLeft(2, '0')}/'
                    '${object.occurredAt.month.toString().padLeft(2, '0')}/'
                    '${object.occurredAt.year} à '
                    '${object.occurredAt.hour.toString().padLeft(2, '0')}:'
                    '${object.occurredAt.minute.toString().padLeft(2, '0')}',
              ),
              if (object.userName != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _InfoTile(
                  iconName: 'user-linear',
                  title: object.userName!,
                  subtitle: object.userTrustScore != null
                      ? 'Confiance ${object.userTrustScore!.round()}%'
                      : 'Publié par un membre',
                ),
              ],
              if (object.contactPhone != null &&
                  object.contactPhone!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                _InfoTile(
                  iconName: 'phone-linear',
                  title: 'Contact',
                  subtitle: object.contactPhone!,
                  trailing: IconButton(
                    icon: Icon(
                      Icons.call_rounded,
                      color: context.colors.primary,
                    ),
                    onPressed: () => _call(object.contactPhone!),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              if (_isOwner) _OwnerActions(object: object),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri)) {
      // Ignore: no dialer available on this platform.
    }
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.object,
    required this.color,
    required this.background,
  });

  final LostFoundObject object;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      width: double.infinity,
      child: object.imageUrl != null
          ? Image.network(
              object.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => ItemArtwork(category: object.category),
            )
          : ItemArtwork(category: object.category),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.object});

  final LostFoundObject object;

  @override
  Widget build(BuildContext context) {
    final isLost = object.type == ItemType.lost;
    final color = isLost ? context.colors.primary : context.colors.tertiary;
    final background = isLost
        ? context.colors.primaryContainer
        : context.colors.tertiaryContainer;
    final label = object.status == ItemStatus.active
        ? object.type.shortLabel
        : object.status.label.toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.iconName,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String iconName;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: AppSpacing.huge - 8,
            height: AppSpacing.huge - 8,
            decoration: BoxDecoration(
              color: context.colors.primaryContainer,
              borderRadius: BorderRadius.circular(AppSpacing.sm),
            ),
            child: Center(
              child: AppIcon(
                iconName,
                size: 19,
                color: context.colors.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.typography.titleMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: context.typography.bodySmall),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _OwnerActions extends ConsumerStatefulWidget {
  const _OwnerActions({required this.object});

  final LostFoundObject object;

  @override
  ConsumerState<_OwnerActions> createState() => _OwnerActionsState();
}

class _OwnerActionsState extends ConsumerState<_OwnerActions> {
  bool _busy = false;

  Future<void> _resolve() async {
    setState(() => _busy = true);
    final notifier = ref.read(objectFormProvider.notifier);
    try {
      await notifier.resolveObject(widget.object.id);
      if (!mounted) return;
      ref.invalidate(objectDetailProvider(widget.object.id));
      ref.invalidate(myObjectsProvider);
      ref.invalidate(myObjectsStatsProvider);
      ref.invalidate(objectsStatsProvider);
      _showMessage('Objet marqué comme récupéré.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Échec : $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'annonce ?'),
        content: const Text('Cette action est définitive.'),
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
    if (confirmed != true) return;

    setState(() => _busy = true);
    final notifier = ref.read(objectFormProvider.notifier);
    try {
      await notifier.deleteObject(widget.object.id);
      if (!mounted) return;
      ref.invalidate(myObjectsProvider);
      ref.invalidate(myObjectsStatsProvider);
      ref.invalidate(objectsStatsProvider);
      ref.invalidate(allObjectsProvider);
      context.pop();
    } catch (error) {
      if (!mounted) return;
      _showMessage('Échec : $error');
      setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.object.status == ItemStatus.active)
          AppButton(
            label: 'Marquer comme récupéré',
            iconName: 'check-circle-bold',
            variant: AppButtonVariant.success,
            loading: _busy,
            onPressed: _busy ? null : _resolve,
          ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Modifier',
                iconName: 'pen-linear',
                variant: AppButtonVariant.secondary,
                onPressed: _busy
                    ? null
                    : () =>
                          context.push(AppRoutes.objectEdit(widget.object.id)),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppButton(
                label: 'Supprimer',
                iconName: 'trash-bin-minimalistic-linear',
                variant: AppButtonVariant.danger,
                onPressed: _busy ? null : _delete,
              ),
            ),
          ],
        ),
      ],
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
        SkeletonBox(width: double.infinity, height: 220),
        SizedBox(height: AppSpacing.lg),
        SkeletonBox(width: 220, height: 26),
        SizedBox(height: AppSpacing.sm),
        SkeletonBox(width: double.infinity, height: 16),
        SizedBox(height: AppSpacing.sm),
        SkeletonBox(width: double.infinity, height: 16),
        SizedBox(height: AppSpacing.lg),
        SkeletonBox(width: double.infinity, height: 72),
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
            Text('Objet introuvable', style: context.typography.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Text(
              error,
              style: context.typography.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
