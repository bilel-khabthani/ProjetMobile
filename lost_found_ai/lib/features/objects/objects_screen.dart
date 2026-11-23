import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/item.dart';
import '../../data/providers.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/status_pill.dart';

class ObjectsScreen extends ConsumerStatefulWidget {
  const ObjectsScreen({super.key, this.initialType = ItemType.lost});

  final ItemType initialType;

  @override
  ConsumerState<ObjectsScreen> createState() => _ObjectsScreenState();
}

class _ObjectsScreenState extends ConsumerState<ObjectsScreen> {
  late ItemType _type = widget.initialType;
  ItemCategory? _category;
  ItemStatus? _status;
  String _sort = 'recent';
  String _query = '';
  final _search = TextEditingController();
  Timer? _debounce;

  static const _categories = ItemCategory.values;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  ItemCatalogQuery get _catalogQuery => ItemCatalogQuery(
    type: _type,
    category: _category,
    status: _status,
    search: _query,
    sort: _sort,
  );

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider(_catalogQuery));

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: context.colors.primary,
        foregroundColor: context.colors.onPrimary,
        onPressed: () => context.push(
          '${AppRoutes.publish}?type=${_type == ItemType.lost ? 'lost' : 'found'}',
        ),
        icon: const Icon(Icons.add),
        label: Text(_type == ItemType.lost ? 'Signaler' : 'Déclarer'),
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: context.colors.primary,
          onRefresh: () async {
            ref.invalidate(catalogProvider(_catalogQuery));
            try {
              await ref.read(catalogProvider(_catalogQuery).future);
            } catch (_) {}
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              14,
              AppSpacing.xl,
              96,
            ),
            children: [
              Row(
                children: [
                  _CircleButton(
                    icon: 'alt-arrow-left-linear',
                    onTap: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go(AppRoutes.home);
                      }
                    },
                  ),
                  const Spacer(),
                  _CircleButton(
                    icon: 'map-linear',
                    onTap: () => context.push(AppRoutes.map),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                _type == ItemType.lost ? 'OBJETS PERDUS' : 'OBJETS TROUVÉS',
                style: context.typography.labelLarge?.copyWith(
                  color: context.colors.primary,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _type == ItemType.lost
                    ? 'Annonces de perte'
                    : 'Annonces d’objets trouvés',
                style: context.typography.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.lg - 4),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<ItemType>(
                  segments: const [
                    ButtonSegment<ItemType>(
                      value: ItemType.lost,
                      label: Text('Perdus'),
                    ),
                    ButtonSegment<ItemType>(
                      value: ItemType.found,
                      label: Text('Trouvés'),
                    ),
                  ],
                  selected: {_type},
                  showSelectedIcon: false,
                  multiSelectionEnabled: false,
                  style: SegmentedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onSelectionChanged: (selection) =>
                      setState(() => _type = selection.first),
                ),
              ),
              const SizedBox(height: AppSpacing.lg - 4),
              TextField(
                controller: _search,
                onChanged: _onSearch,
                decoration: InputDecoration(
                  hintText: 'Rechercher un titre, un lieu…',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.sm,
                      right: AppSpacing.xs,
                    ),
                    child: AppIcon(
                      'magnifer-linear',
                      size: 18,
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 0),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _HorizontalChips(
                children: [
                  _MiniChip(
                    label: 'Toutes',
                    selected: _category == null,
                    onTap: () => setState(() => _category = null),
                  ),
                  for (final category in _categories)
                    _MiniChip(
                      label: category.label,
                      selected: _category == category,
                      onTap: () => setState(() => _category = category),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              _HorizontalChips(
                children: [
                  _MiniChip(
                    label: 'En cours',
                    selected: _status == null,
                    onTap: () => setState(() => _status = null),
                  ),
                  _MiniChip(
                    label: 'Correspondance',
                    selected: _status == ItemStatus.matched,
                    onTap: () => setState(() => _status = ItemStatus.matched),
                  ),
                  _MiniChip(
                    label: 'Récupérés',
                    selected: _status == ItemStatus.recovered,
                    onTap: () => setState(() => _status = ItemStatus.recovered),
                  ),
                  _MiniChip(
                    label: 'Clôturées',
                    selected: _status == ItemStatus.closed,
                    onTap: () => setState(() => _status = ItemStatus.closed),
                  ),
                  _MiniChip(
                    label: 'Plus récent',
                    selected: _sort == 'recent',
                    onTap: () => setState(() => _sort = 'recent'),
                  ),
                  _MiniChip(
                    label: 'Plus ancien',
                    selected: _sort == 'oldest',
                    onTap: () => setState(() => _sort = 'oldest'),
                  ),
                  _MiniChip(
                    label: 'Titre',
                    selected: _sort == 'title',
                    onTap: () => setState(() => _sort = 'title'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              catalog.when(
                loading: () => const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.huge),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => _Message(
                  title: 'Chargement impossible',
                  body:
                      'Le serveur ne répond pas. Vérifiez la connexion puis réessayez.',
                  action: 'Réessayer',
                  onTap: () => ref.invalidate(catalogProvider(_catalogQuery)),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return _Message(
                      title: 'Aucune annonce',
                      body:
                          _query.isEmpty && _category == null && _status == null
                          ? 'Soyez le premier à publier dans cette catégorie.'
                          : 'Aucun résultat pour ces filtres.',
                      action: 'Publier',
                      onTap: () => context.push(
                        '${AppRoutes.publish}?type=${_type == ItemType.lost ? 'lost' : 'found'}',
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final item in items) ...[
                        _ObjectTile(
                          item: item,
                          onTap: () =>
                              context.push(AppRoutes.itemDetail(item.id)),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ObjectTile extends StatelessWidget {
  const _ObjectTile({required this.item, required this.onTap});

  final Item item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = item.occurredAt.toLocal();
    final dateLabel =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.sm),
            child: SizedBox(
              width: 64,
              height: 64,
              child: item.imageUrl == null
                  ? ColoredBox(
                      color: context.colors.surfaceContainerHighest,
                      child: AppIcon(
                        'box-linear',
                        color: item.type == ItemType.lost
                            ? context.colors.primary
                            : context.colors.tertiary,
                      ),
                    )
                  : Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => ColoredBox(
                        color: context.colors.surfaceContainerHighest,
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: context.typography.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.place.isEmpty ? item.category.label : item.place,
                  style: context.typography.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    StatusPill(type: item.type, compact: true),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        '$dateLabel · ${item.status.label}',
                        style: context.typography.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HorizontalChips extends StatelessWidget {
  const _HorizontalChips({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (_, index) => children[index],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
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

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final String icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: AppIcon(icon, size: 20, color: context.colors.onSurfaceVariant),
      style: IconButton.styleFrom(
        backgroundColor: context.colors.surfaceContainerLow,
        foregroundColor: context.colors.onSurfaceVariant,
        minimumSize: const Size(48, 48),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.title,
    required this.body,
    required this.action,
    required this.onTap,
  });

  final String title;
  final String body;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 36),
      child: Column(
        children: [
          Text(
            title,
            style: context.typography.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            body,
            style: context.typography.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(onPressed: onTap, child: Text(action)),
        ],
      ),
    );
  }
}
