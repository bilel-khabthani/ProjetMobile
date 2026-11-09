import 'dart:async';

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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Objets'),
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
          const SizedBox(width: 4),
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
                  color: AppColors.primary,
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
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
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
        hintStyle: AppText.body.copyWith(color: AppColors.textTertiary),
        prefixIcon: const Icon(Icons.search_rounded,
            color: AppColors.textTertiary, size: 21),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
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
    final options = <({String label, ItemType? type})>[
      (label: 'Tous', type: null),
      (label: 'Perdus', type: ItemType.lost),
      (label: 'Trouvés', type: ItemType.found),
    ];

    return Row(
      children: [
        for (final option in options) ...[
          Expanded(
            child: PressableScale(
              onTap: () => onChanged(option.type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected == option.type
                      ? AppColors.primary
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: selected == option.type
                        ? AppColors.primary
                        : AppColors.border,
                  ),
                ),
                child: Center(
                  child: Text(
                    option.label,
                    style: AppText.tiny.copyWith(
                      color: selected == option.type
                          ? Colors.white
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (option != options.last) const SizedBox(width: AppSpacing.xs),
        ],
      ],
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
      height: 36,
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
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(iconName, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppText.tiny.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
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
    final color = isLost ? AppColors.lost : AppColors.found;
    final soft = isLost ? AppColors.lostSoft : AppColors.foundSoft;

    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: SizedBox(
                width: 68,
                height: 68,
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
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: soft,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          object.type.shortLabel,
                          style: AppText.tiny.copyWith(
                            color: color,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(object.formattedDate, style: AppText.tiny),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    object.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyStrong,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.place_outlined,
                          size: 13, color: AppColors.textTertiary),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          object.placeLabel.isEmpty
                              ? object.category.label
                              : object.placeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.tiny,
                        ),
                      ),
                    ],
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
            const Icon(Icons.search_off_rounded,
                size: 52, color: AppColors.textTertiary),
            const SizedBox(height: AppSpacing.md),
            Text(
              hasFilters ? 'Aucun résultat' : 'Aucun objet publié',
              style: AppText.h2,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              hasFilters
                  ? 'Essaie d\'autres filtres ou une autre recherche.'
                  : 'Sois le premier à publier une annonce.',
              style: AppText.body,
              textAlign: TextAlign.center,
            ),
            if (hasFilters) ...[
              const SizedBox(height: AppSpacing.lg),
              TextButton(onPressed: onClear, child: const Text('Réinitialiser')),
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
            const Icon(Icons.cloud_off_rounded,
                size: 48, color: AppColors.danger),
            const SizedBox(height: AppSpacing.md),
            Text('Impossible de charger les objets', style: AppText.h2),
            const SizedBox(height: AppSpacing.sm),
            Text(error, style: AppText.body, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            TextButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
