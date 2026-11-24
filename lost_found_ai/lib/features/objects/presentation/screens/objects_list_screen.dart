import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/api_client.dart';
import '../../../../data/models/item.dart';
import '../../../../widgets/app_bottom_sheet.dart';
import '../../../../widgets/app_button.dart';
import '../../../../widgets/app_icon.dart';
import '../../../../widgets/app_state_view.dart';
import '../../../../widgets/photo_placeholder.dart';
import '../../../../widgets/skeleton.dart';
import '../../../../widgets/status_pill.dart';
import '../../data/providers/objects_providers.dart';

class ObjectsListScreen extends ConsumerStatefulWidget {
  const ObjectsListScreen({
    super.key,
    this.allowAllTypes = false,
    this.fallbackType = ItemType.lost,
  });

  final bool allowAllTypes;
  final ItemType? fallbackType;

  @override
  ConsumerState<ObjectsListScreen> createState() => _ObjectsListScreenState();
}

class _ObjectsListScreenState extends ConsumerState<ObjectsListScreen> {
  late final TextEditingController _searchController;
  Timer? _debounce;
  ObjectFilter _filter = const ObjectFilter();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  ItemType? get _routeType {
    final value = GoRouterState.of(context).uri.queryParameters['type'];
    return switch (value?.toLowerCase()) {
      'lost' => ItemType.lost,
      'found' => ItemType.found,
      _ => widget.fallbackType,
    };
  }

  ObjectFilter get _effectiveFilter {
    final type = _routeType;
    return _filter.copyWith(type: type, clearType: type == null);
  }

  int get _narrowingFilterCount =>
      (_filter.category != null ? 1 : 0) +
      (_filter.status != null ? 1 : 0) +
      (_filter.searchQuery.isNotEmpty ? 1 : 0);

  String get _publishLocation {
    if (widget.allowAllTypes) return AppRoutes.objectsAdd;
    final type = switch (_routeType) {
      ItemType.found => 'found',
      _ => 'lost',
    };
    return '${AppRoutes.publish}?type=$type';
  }

  String get _publishLabel {
    if (widget.allowAllTypes) return 'Publier';
    return _routeType == ItemType.found ? 'Déclarer' : 'Signaler';
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _debounce = null;
      final query = value.trim();
      if (_filter.searchQuery == query) return;
      setState(() => _filter = _filter.copyWith(searchQuery: query));
    });
  }

  void _commitPendingSearch() {
    final timer = _debounce;
    if (timer == null) return;
    timer.cancel();
    _debounce = null;
    final query = _searchController.text.trim();
    if (_filter.searchQuery == query) return;
    setState(() => _filter = _filter.copyWith(searchQuery: query));
  }

  void _setType(ItemType? type) {
    final state = GoRouterState.of(context);
    final params = Map<String, String>.from(state.uri.queryParameters);
    if (type == null) {
      params.remove('type');
    } else {
      params['type'] = type.apiValue;
    }
    final location = state.uri
        .replace(queryParameters: params.isEmpty ? null : params)
        .toString();
    context.push(location);
  }

  void _setCategory(ItemCategory? category) {
    setState(() {
      _filter = category == null
          ? _filter.copyWith(clearCategory: true)
          : _filter.copyWith(category: category);
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _debounce = null;
    _searchController.clear();
    setState(() => _filter = _filter.copyWith(searchQuery: ''));
  }

  void _resetFilters() {
    _debounce?.cancel();
    _debounce = null;
    _searchController.clear();
    setState(() => _filter = const ObjectFilter());
  }

  void _applyFilters(ObjectFilter filter) {
    _commitPendingSearch();
    setState(() => _filter = filter.copyWith(searchQuery: _filter.searchQuery));
  }

  void _openFilters() {
    _commitPendingSearch();
    showAppBottomSheet<void>(
      context: context,
      semanticLabel: 'Filtres du catalogue',
      builder: (_) => _FilterSheet(
        filter: _filter,
        onApply: _applyFilters,
        onReset: () {
          Navigator.of(context).pop();
          _resetFilters();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filter = _effectiveFilter;
    final objectsAsync = ref.watch(objectsProvider(filter));
    final routeType = _routeType;

    final headline = switch (routeType) {
      ItemType.lost => 'Chaque objet perdu a une histoire.',
      ItemType.found => 'Chaque objet trouvé attend son propriétaire.',
      _ => 'Chaque objet attend sa seconde chance.',
    };
    final description = switch (routeType) {
      ItemType.lost =>
        'Parcourez les annonces et retrouvez ce qui compte.',
      ItemType.found =>
        'Aidez la communauté à réunir les objets et leurs propriétaires.',
      _ => 'Explorez toutes les annonces de la communauté.',
    };

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: context.colors.primary,
          onRefresh: () async {
            ref.invalidate(objectsProvider(filter));
            try {
              await ref.read(objectsProvider(filter).future);
            } catch (error) {
              if (!mounted || !context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(catalogFriendlyErrorMessage(error))),
              );
            }
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.sm,
              AppSpacing.xl,
              112,
            ),
            children: [
              Row(
                children: [
                  _CircleButton(
                    icon: 'alt-arrow-left-linear',
                    semanticLabel: 'Retour',
                    onTap: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go(AppRoutes.home);
                      }
                    },
                  ),
                  const Spacer(),
                  if (widget.allowAllTypes)
                    TextButton(
                      onPressed: () => context.push(AppRoutes.myObjects),
                      child: Text(
                        'Mes annonces',
                        style: context.typography.labelLarge,
                      ),
                    ),
                  if (widget.allowAllTypes)
                    const SizedBox(width: AppSpacing.xs),
                  _CircleButton(
                    icon: 'map-linear',
                    semanticLabel: 'Voir la carte',
                    onTap: () => context.push(AppRoutes.map),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'VOTRE CATALOGUE',
                style: context.typography.labelLarge?.copyWith(
                  color: context.colors.primary,
                  letterSpacing: 0.7,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(headline, style: context.typography.headlineMedium),
              const SizedBox(height: 6),
              Text(
                description,
                style: context.typography.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SegmentedButton<ItemType?>(
                segments: [
                  if (widget.allowAllTypes)
                    const ButtonSegment<ItemType?>(
                      value: null,
                      label: Text('Tous'),
                    ),
                  const ButtonSegment<ItemType?>(
                    value: ItemType.lost,
                    label: Text('Perdus'),
                  ),
                  const ButtonSegment<ItemType?>(
                    value: ItemType.found,
                    label: Text('Trouvés'),
                  ),
                ],
                selected: {routeType},
                showSelectedIcon: false,
                multiSelectionEnabled: false,
                style: SegmentedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                onSelectionChanged: (selection) =>
                    _setType(selection.isEmpty ? null : selection.first),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Rechercher un objet ou un lieu',
                  hintText: 'Rechercher un objet, un lieu…',
                  prefixIcon: const Icon(Icons.search_rounded, size: 21),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Effacer la recherche',
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: _clearSearch,
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: ItemCategory.values.length + 1,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.xs),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _CategoryChip(
                        label: 'Toutes',
                        iconName: 'widget-linear',
                        selected: _filter.category == null,
                        onTap: () => _setCategory(null),
                      );
                    }
                    final category = ItemCategory.values[index - 1];
                    return _CategoryChip(
                      label: category.label,
                      iconName: categoryIconName(category),
                      selected: _filter.category == category,
                      onTap: () => _setCategory(category),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _FilterBar(
                filterCount: _narrowingFilterCount,
                onTap: _openFilters,
              ),
              const SizedBox(height: AppSpacing.lg),
              objectsAsync.when(
                loading: () => const _CatalogSkeleton(),
                error: (error, _) => AppStateView(
                  icon: Icons.cloud_off_rounded,
                  title: 'Chargement impossible',
                  message: catalogFriendlyErrorMessage(error),
                  actionLabel: 'Réessayer',
                  onAction: () => ref.invalidate(objectsProvider(filter)),
                  tone: AppStateTone.error,
                ),
                data: (objects) {
                  if (objects.isEmpty) {
                    return AppStateView(
                      icon: Icons.search_off_rounded,
                      title: _narrowingFilterCount == 0
                          ? 'Aucune annonce'
                          : 'Aucun résultat',
                      message: _narrowingFilterCount == 0
                          ? 'Soyez le premier à publier dans cette catégorie.'
                          : 'Essayez d’autres filtres ou une autre recherche.',
                      actionLabel: _narrowingFilterCount == 0
                          ? _publishLabel
                          : 'Réinitialiser',
                      onAction: _narrowingFilterCount == 0
                          ? () => context.push(_publishLocation)
                          : _resetFilters,
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ResultHeader(count: objects.length),
                      const SizedBox(height: AppSpacing.md),
                      for (final object in objects) ...[
                        _ObjectCard(
                          object: object,
                          onTap: () =>
                              context.push(AppRoutes.objectDetail(object.id)),
                        ),
                        const SizedBox(height: AppSpacing.sm + 2),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: context.colors.primary,
        foregroundColor: context.colors.onPrimary,
        onPressed: () => context.push(_publishLocation),
        icon: const Icon(Icons.add_rounded),
        label: Text(_publishLabel),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final String icon;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: semanticLabel,
      onPressed: onTap,
      icon: AppIcon(icon, size: 20, color: context.colors.onSurfaceVariant),
      style: IconButton.styleFrom(
        backgroundColor: context.colors.surfaceContainerLow,
        side: BorderSide(color: context.colors.outlineVariant),
        minimumSize: const Size(48, 48),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.iconName,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String iconName;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      avatar: AppIcon(
        iconName,
        size: 16,
        color: selected
            ? context.colors.onPrimaryContainer
            : context.colors.onSurfaceVariant,
      ),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 14,
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.filterCount, required this.onTap});

  final int filterCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final suffix = filterCount == 0
        ? ''
        : ', $filterCount filtre${filterCount > 1 ? 's' : ''} actif${filterCount > 1 ? 's' : ''}';
    final label = 'Filtrer et trier les annonces$suffix';
    return Row(
      children: [
        ExcludeSemantics(
          child: Row(
            children: [
              Icon(
                Icons.tune_rounded,
                size: 17,
                color: context.colors.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                filterCount == 0
                    ? 'Filtrer et trier les annonces'
                    : '$filterCount filtre${filterCount > 1 ? 's' : ''} actif${filterCount > 1 ? 's' : ''}',
                style: context.typography.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: label,
              onPressed: onTap,
              icon: const Icon(Icons.tune_rounded),
              style: IconButton.styleFrom(
                backgroundColor: context.colors.surfaceContainerLow,
                side: BorderSide(color: context.colors.outlineVariant),
                minimumSize: const Size(48, 48),
              ),
            ),
            if (filterCount > 0)
              Positioned(
                right: -2,
                top: -2,
                child: ExcludeSemantics(
                  child: Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: context.colors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.colors.surface,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      '$filterCount',
                      style: context.typography.labelSmall?.copyWith(
                        color: context.colors.onPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: context.colors.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.auto_awesome_rounded,
            size: 17,
            color: context.colors.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: AppSpacing.xs + 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count annonce${count > 1 ? 's' : ''} à explorer',
                style: context.typography.titleMedium,
              ),
              Text(
                'Sélectionne une annonce pour voir les détails',
                style: context.typography.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CatalogSkeleton extends StatelessWidget {
  const _CatalogSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(3, (index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
          child: AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SkeletonBox(
                  width: double.infinity,
                  height: 148,
                  borderRadius: 0,
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SkeletonBox(width: 180, height: 16),
                      SizedBox(height: 10),
                      SkeletonBox(width: 130, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _ObjectCard extends StatelessWidget {
  const _ObjectCard({required this.object, required this.onTap});

  final LostFoundObject object;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLost = object.type == ItemType.lost;
    final accent = isLost ? context.colors.primary : context.colors.tertiary;
    final cardLabel = buildObjectCardSemanticsLabel(object);

    return Semantics(
      label: cardLabel,
      button: true,
      onTap: onTap,
      container: true,
      child: ExcludeSemantics(
        child: AppCard(
          onTap: onTap,
          padding: EdgeInsets.zero,
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              Hero(
                tag: 'object-image-${object.id}',
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.lg),
                  ),
                  child: SizedBox(
                    height: 156,
                    width: double.infinity,
                    child: object.imageUrl != null
                        ? Image.network(
                            object.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => ItemArtwork(
                              category: object.category,
                              width: double.infinity,
                              height: 156,
                              borderRadius: 0,
                            ),
                          )
                        : ItemArtwork(
                            category: object.category,
                            width: double.infinity,
                            height: 156,
                            borderRadius: 0,
                          ),
                  ),
                ),
              ),
              Positioned(
                top: AppSpacing.sm,
                left: AppSpacing.sm,
                child: StatusPill(type: object.type),
              ),
              if (object.distanceKm != null)
                Positioned(
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.scrim.withValues(alpha: 0.62),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '${object.distanceKm!.toStringAsFixed(1)} km',
                      style: context.typography.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: isLost
                            ? context.colors.primaryContainer
                            : context.colors.tertiaryContainer,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        categoryIcon(object.category),
                        size: 17,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs + 2),
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
                          Text(
                            object.placeLabel.isEmpty
                                ? object.category.label
                                : object.placeLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.typography.bodySmall?.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 15,
                      color: context.colors.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: context.colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      object.formattedDate,
                      style: context.typography.labelSmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        color: context.colors.onSurfaceVariant,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      object.status.label,
                      style: context.typography.labelSmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ],
        ),
      ),
    ),
  );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.filter,
    required this.onApply,
    required this.onReset,
  });

  final ObjectFilter filter;
  final void Function(ObjectFilter filter) onApply;
  final VoidCallback onReset;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late ObjectFilter _filter = widget.filter;

  static const _statusOptions = <ItemStatus?>[
    null,
    ItemStatus.matched,
    ItemStatus.recovered,
    ItemStatus.closed,
  ];

  static const _sortOptions = <String, String>{
    'recent': 'Plus récent',
    'oldest': 'Plus ancien',
    'title': 'Titre',
  };

  String _statusLabel(ItemStatus? status) => switch (status) {
    null => 'En cours',
    ItemStatus.active => 'En cours',
    ItemStatus.matched => 'Correspondance',
    ItemStatus.disputed => 'En litige',
    ItemStatus.recovered => 'Récupérés',
    ItemStatus.closed => 'Clôturées',
  };

  void _setStatus(ItemStatus? status) {
    setState(() {
      _filter = status == null
          ? _filter.copyWith(clearStatus: true)
          : _filter.copyWith(status: status);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Affiner les résultats', style: context.typography.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'Statut et ordre d’affichage des annonces.',
              style: context.typography.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Statut', style: context.typography.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final status in _statusOptions)
                  ChoiceChip(
                    label: Text(_statusLabel(status)),
                    selected: _filter.status == status,
                    showCheckmark: false,
                    onSelected: (_) => _setStatus(status),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Trier par', style: context.typography.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Column(
              children: [
                for (final entry in _sortOptions.entries)
                  ListTile(
                    title: Text(entry.value),
                    selected: entry.key == _filter.sort,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    trailing: Icon(
                      entry.key == _filter.sort
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: entry.key == _filter.sort
                          ? context.colors.primary
                          : context.colors.onSurfaceVariant,
                    ),
                    onTap: () =>
                        setState(() => _filter = _filter.copyWith(sort: entry.key)),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Réinitialiser',
                    variant: AppButtonVariant.secondary,
                    height: 52,
                    onPressed: widget.onReset,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    label: 'Appliquer',
                    height: 52,
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onApply(_filter);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

@visibleForTesting
String buildObjectCardSemanticsLabel(LostFoundObject object) {
  return [
    object.type == ItemType.lost ? 'Perdu' : 'Trouvé',
    object.title,
    object.placeLabel.isEmpty ? object.category.label : object.placeLabel,
    if (object.distanceKm != null) '${object.distanceKm!.toStringAsFixed(1)} km',
    object.formattedDate,
    object.status.label,
  ].join(', ');
}

@visibleForTesting
String catalogFriendlyErrorMessage(Object error) {
  if (error is ApiException) return error.userMessage;
  return 'Le catalogue est momentanément indisponible. Vérifiez votre connexion puis réessayez.';
}
