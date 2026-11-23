import 'dart:async';

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

class ObjectsListScreen extends ConsumerStatefulWidget {
  const ObjectsListScreen({super.key});

  @override
  ConsumerState<ObjectsListScreen> createState() => _ObjectsListScreenState();
}

class _ObjectsListScreenState extends ConsumerState<ObjectsListScreen> {
  late final TextEditingController _searchController;
  Timer? _debounce;
  ObjectFilter _filter = const ObjectFilter();
  bool _didInitFilterFromRoute = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitFilterFromRoute) return;
    _didInitFilterFromRoute = true;
    // GoRouterState relies on an InheritedWidget, so it cannot be read from
    // initState(). didChangeDependencies is the first safe hook.
    final typeParam = GoRouterState.of(context).uri.queryParameters['type'];
    if (typeParam != null) {
      _filter = _filter.copyWith(type: itemTypeFromApiValue(typeParam));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _setSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _filter = value.trim().isEmpty
            ? _filter.copyWith(searchQuery: '')
            : _filter.copyWith(searchQuery: value.trim());
      });
    });
  }

  void _setType(ItemType? type) {
    setState(() {
      _filter = type == null
          ? _filter.copyWith(clearType: true)
          : _filter.copyWith(type: type);
    });
  }

  void _setCategory(ItemCategory? category) {
    setState(() {
      _filter = category == null
          ? _filter.copyWith(clearCategory: true)
          : _filter.copyWith(category: category);
    });
  }

  @override
  Widget build(BuildContext context) {
    final objectsAsync = ref.watch(objectsProvider(_filter));

    return Scaffold(
      appBar: AppBar(
        title: Text('Objets', style: context.typography.titleLarge),
        actions: [
          IconButton(
            tooltip: 'Carte',
            icon: const Icon(Icons.map_outlined),
            onPressed: () => context.push(AppRoutes.objectsMap),
          ),
          IconButton(
            tooltip: 'Mes annonces',
            icon: const Icon(Icons.person_outline_rounded),
            onPressed: () => context.push(AppRoutes.objectMyList),
          ),
          const SizedBox(width: AppSpacing.xs - 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xs,
              AppSpacing.xl,
              AppSpacing.sm,
            ),
            child: Column(
              children: [
                _SearchField(
                  controller: _searchController,
                  onChanged: _setSearch,
                ),
                const SizedBox(height: AppSpacing.sm),
                _TypeFilter(selected: _filter.type, onChanged: _setType),
                const SizedBox(height: AppSpacing.sm),
                _CategoryFilter(
                  selected: _filter.category,
                  onChanged: _setCategory,
                ),
              ],
            ),
          ),
          Expanded(
            child: objectsAsync.when(
              loading: () => ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.xl),
                itemCount: 4,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (_, _) => const SkeletonBox(
                  width: double.infinity,
                  height: 92,
                  borderRadius: AppRadius.md,
                ),
              ),
              error: (error, _) => _ErrorState(
                error: error.toString(),
                onRetry: () => ref.invalidate(objectsProvider(_filter)),
              ),
              data: (objects) {
                if (objects.isEmpty) {
                  return _EmptyState(
                    hasFilters: _filter.hasActiveCriteria,
                    onClear: () => setState(() {
                      _searchController.clear();
                      _filter = const ObjectFilter();
                    }),
                  );
                }
                return RefreshIndicator(
                  color: context.colors.primary,
                  onRefresh: () async {
                    ref.invalidate(objectsProvider(_filter));
                    await ref.read(objectsProvider(_filter).future);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      0,
                      AppSpacing.xl,
                      AppSpacing.xxxl,
                    ),
                    itemCount: objects.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final object = objects[index];
                      return _ObjectTile(
                        object: object,
                        onTap: () =>
                            context.push(AppRoutes.objectDetail(object.id)),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
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

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Rechercher un objet, un lieu…',
        prefixIcon: Icon(Icons.search_rounded, size: 21),
      ),
    );
  }
}

class _TypeFilter extends StatelessWidget {
  const _TypeFilter({required this.selected, required this.onChanged});

  final ItemType? selected;
  final ValueChanged<ItemType?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<ItemType?>(
        segments: const [
          ButtonSegment<ItemType?>(value: null, label: Text('Tous')),
          ButtonSegment<ItemType?>(value: ItemType.lost, label: Text('Perdus')),
          ButtonSegment<ItemType?>(
            value: ItemType.found,
            label: Text('Trouvés'),
          ),
        ],
        selected: {selected},
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

class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({required this.selected, required this.onChanged});

  final ItemCategory? selected;
  final ValueChanged<ItemCategory?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _CategoryChip(
            label: 'Toutes',
            iconName: 'widget-linear',
            selected: selected == null,
            onTap: () => onChanged(null),
          ),
          for (final category in ItemCategory.values) ...[
            const SizedBox(width: AppSpacing.xs),
            _CategoryChip(
              label: category.label,
              iconName: categoryIconName(category),
              selected: selected == category,
              onTap: () => onChanged(category),
            ),
          ],
        ],
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
    return FilterChip(
      label: Text(label),
      avatar: AppIcon(
        iconName,
        size: 16,
        color: context.colors.onSurfaceVariant,
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

class _ObjectTile extends StatelessWidget {
  const _ObjectTile({required this.object, required this.onTap});

  final LostFoundObject object;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLost = object.type == ItemType.lost;
    final color = isLost ? context.colors.primary : context.colors.tertiary;
    final soft = isLost
        ? context.colors.primaryContainer
        : context.colors.tertiaryContainer;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.sm),
            child: SizedBox(
              width: AppSpacing.huge + 20,
              height: AppSpacing.huge + 20,
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: soft,
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
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        object.formattedDate,
                        style: context.typography.labelSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  object.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.titleMedium,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: 13,
                      color: context.colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        object.placeLabel.isEmpty
                            ? object.category.label
                            : object.placeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.typography.bodySmall,
                      ),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFilters, required this.onClear});

  final bool hasFilters;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 52,
              color: context.colors.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              hasFilters ? 'Aucun résultat' : 'Aucun objet publié',
              style: context.typography.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              hasFilters
                  ? 'Essaie d\'autres filtres ou une autre recherche.'
                  : 'Sois le premier à publier une annonce.',
              style: context.typography.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (hasFilters) ...[
              const SizedBox(height: AppSpacing.lg),
              TextButton(
                onPressed: onClear,
                child: const Text('Réinitialiser'),
              ),
            ],
          ],
        ),
      ),
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
              'Impossible de charger les objets',
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
