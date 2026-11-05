import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_strings.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/item.dart';
import '../../data/models/item_match.dart';
import '../../data/providers.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/scene_art.dart';
import '../../widgets/skeleton.dart';
import '../home/widgets/match_card.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  ItemCategory? _category;

  static const _categories = [
    ItemCategory.bag,
    ItemCategory.phone,
    ItemCategory.keys,
    ItemCategory.wallet,
    ItemCategory.documents,
    ItemCategory.other,
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(nearbyFoundProvider);
    try {
      await ref.read(nearbyFoundProvider.future);
    } catch (_) {
      // L'etat vide/erreur est gere plus bas.
    }
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _category = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final nearby = ref.watch(nearbyFoundProvider);
    final myItems = ref.watch(myItemsProvider);
    final matches = ref.watch(matchesProvider).valueOrNull ?? const <ItemMatch>[];
    final items = (nearby.valueOrNull ?? const <Map<String, dynamic>>[])
        .map(NearbyFound.fromJson)
        .toList(growable: false);
    final hasLostItem =
        myItems.valueOrNull?.any((item) => item.type == ItemType.lost) ?? false;
    final normalizedQuery = _query.trim().toLowerCase();
    final filtered = items.where((item) {
      final matchesQuery =
          normalizedQuery.isEmpty ||
          item.title.toLowerCase().contains(normalizedQuery) ||
          item.description.toLowerCase().contains(normalizedQuery) ||
          item.placeLabel.toLowerCase().contains(normalizedQuery) ||
          item.finderName.toLowerCase().contains(normalizedQuery);
      final matchesCategory = _category == null || item.category == _category;
      return matchesQuery && matchesCategory;
    }).toList(growable: false)
      ..sort((a, b) => b.score.compareTo(a.score));

    final filtersActive = normalizedQuery.isNotEmpty || _category != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const AppBottomNav(active: AppTab.explore),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AUTOUR DE VOUS',
                          style: AppText.eyebrow.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(AppStrings.exploreTitle, style: AppText.h1),
                        const SizedBox(height: 4),
                        Text(
                          AppStrings.exploreSubtitle,
                          style: AppText.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.foundSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const AppIcon(
                      'map-point-linear',
                      size: 23,
                      color: AppColors.mintDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _SearchField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                onClear: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _FilterChip(
                      label: 'Tout',
                      selected: _category == null,
                      onTap: () => setState(() => _category = null),
                    ),
                    for (final category in _categories) ...[
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: category.label,
                        selected: _category == category,
                        onTap: () => setState(() => _category = category),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    nearby.isLoading
                        ? 'Recherche en cours…'
                        : '${filtered.length} objet${filtered.length > 1 ? 's' : ''} trouvé${filtered.length > 1 ? 's' : ''}',
                    style: AppText.bodyStrong,
                  ),
                  const Spacer(),
                  if (filtersActive)
                    GestureDetector(
                      onTap: _clearFilters,
                      child: Text(
                        'Réinitialiser',
                        style: AppText.label.copyWith(color: AppColors.primary),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (nearby.isLoading)
                const _ExploreSkeleton()
              else if (nearby.hasError && !hasLostItem)
                _ExploreEmpty(
                  variant: SceneVariant.search,
                  title: AppStrings.exploreNeedsLostTitle,
                  body: AppStrings.exploreNeedsLostBody,
                  cta: 'Publier une annonce',
                  onTap: () => context.push('${AppRoutes.publish}?type=lost'),
                )
              else if (!hasLostItem && items.isEmpty)
                _ExploreEmpty(
                  variant: SceneVariant.search,
                  title: AppStrings.exploreNeedsLostTitle,
                  body: AppStrings.exploreNeedsLostBody,
                  cta: 'Publier une annonce',
                  onTap: () => context.push('${AppRoutes.publish}?type=lost'),
                )
              else if (filtered.isEmpty)
                _ExploreEmpty(
                  variant: SceneVariant.search,
                  title: filtersActive
                      ? 'Aucun résultat'
                      : AppStrings.exploreEmptyTitle,
                  body: filtersActive
                      ? 'Essayez un autre mot-clé ou une autre catégorie.'
                      : AppStrings.exploreEmptyBody,
                  cta: filtersActive ? 'Réinitialiser' : 'Actualiser',
                  onTap: filtersActive ? _clearFilters : _refresh,
                )
              else
                Column(
                  children: [
                    for (var i = 0; i < filtered.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      Builder(
                        builder: (context) {
                          final item = filtered[i];
                          String? matchId;
                          for (final match in matches) {
                            if (match.foundItemTitle.toLowerCase() ==
                                item.title.toLowerCase()) {
                              matchId = match.id;
                              break;
                            }
                          }
                          return NearbyFoundTile(
                            item: item,
                            onTap: () => showNearbyFoundSheet(
                              context,
                              item,
                              matchId: matchId,
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: AppText.body,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: AppStrings.exploreSearchHint,
          hintStyle: AppText.body.copyWith(color: AppColors.textTertiary),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 14, right: 10),
            child: AppIcon(
              'magnifer-linear',
              size: 20,
              color: AppColors.textTertiary,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  onPressed: onClear,
                  icon: const AppIcon(
                    'close-circle-linear',
                    size: 19,
                    color: AppColors.textTertiary,
                  ),
                ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
          boxShadow: selected ? AppShadows.primary : null,
        ),
        child: Text(
          label,
          style: AppText.label.copyWith(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ExploreEmpty extends StatelessWidget {
  const _ExploreEmpty({
    required this.variant,
    required this.title,
    required this.body,
    required this.cta,
    required this.onTap,
  });

  final SceneVariant variant;
  final String title;
  final String body;
  final String cta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          SceneArt(variant: variant, size: 120),
          const SizedBox(height: 10),
          Text(title, style: AppText.h3, textAlign: TextAlign.center),
          const SizedBox(height: 5),
          Text(
            body,
            style: AppText.caption.copyWith(height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                cta,
                style: AppText.label.copyWith(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExploreSkeleton extends StatelessWidget {
  const _ExploreSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        4,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.divider),
            ),
            child: const Row(
              children: [
                SkeletonBox(width: 60, height: 60, borderRadius: 16),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 150, height: 13),
                      SizedBox(height: 8),
                      SkeletonBox(width: 110, height: 10),
                      SizedBox(height: 8),
                      SkeletonBox(width: 90, height: 9),
                    ],
                  ),
                ),
                SkeletonBox(width: 42, height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
