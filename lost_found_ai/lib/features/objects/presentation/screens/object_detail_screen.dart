import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../data/models/item.dart';
import '../../../../data/providers.dart';
import '../../../../widgets/app_button.dart';
import '../../../../widgets/app_icon.dart';
import '../../../../widgets/photo_placeholder.dart';
import '../../../../widgets/pressable_scale.dart';
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
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
        data: (object) => _Content(
          object: object,
          currentUserId: user?.id,
        ),
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
    final color = isLost ? AppColors.lost : AppColors.found;
    final background = isLost ? AppColors.lostSoft : AppColors.foundSoft;

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
                  Expanded(child: Text(object.title, style: AppText.h1)),
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
                          style: AppText.tiny.copyWith(
                            color: color,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(object.formattedDate, style: AppText.caption),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(object.description, style: AppText.body),
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
                    icon: const Icon(Icons.call_rounded,
                        color: AppColors.found),
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
  const _Hero({required this.object, required this.color, required this.background});

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
              errorBuilder: (_, __, ___) =>
                  ItemArtwork(category: object.category),
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
    final color = isLost ? AppColors.lost : AppColors.found;
    final background = isLost ? AppColors.lostSoft : AppColors.foundSoft;
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
        style: AppText.tiny.copyWith(color: color, fontWeight: FontWeight.w800),
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Center(
              child: AppIcon(iconName, size: 19, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.bodyStrong),
                const SizedBox(height: 2),
                Text(subtitle, style: AppText.caption),
              ],
            ),
          ),
          if (trailing != null) trailing!,
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
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
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
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
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
                    : () => context.push(AppRoutes.objectEdit(widget.object.id)),
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
            const Icon(Icons.cloud_off_rounded,
                size: 48, color: AppColors.danger),
            const SizedBox(height: AppSpacing.md),
            Text('Objet introuvable', style: AppText.h2),
            const SizedBox(height: AppSpacing.sm),
            Text(error, style: AppText.body, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            PressableScale(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  'Réessayer',
                  style: AppText.label.copyWith(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
