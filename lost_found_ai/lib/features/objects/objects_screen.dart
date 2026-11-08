import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
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
    final accent = _type == ItemType.lost ? AppColors.lost : AppColors.found;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: accent,
        foregroundColor: _type == ItemType.lost ? Colors.white : AppColors.mintDark,
        onPressed: () => context.push(
          '${AppRoutes.publish}?type=${_type == ItemType.lost ? 'lost' : 'found'}',
        ),
        icon: const Icon(Icons.add),
        label: Text(_type == ItemType.lost ? 'Signaler' : 'Déclarer'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(catalogProvider(_catalogQuery));
            try {
              await ref.read(catalogProvider(_catalogQuery).future);
            } catch (_) {}
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 96),
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
              const SizedBox(height: 16),
              Text(
                _type == ItemType.lost ? 'OBJETS PERDUS' : 'OBJETS TROUVÉS',
                style: AppText.eyebrow.copyWith(color: AppColors.primary),
              ),
              const SizedBox(height: 6),
              Text(
                _type == ItemType.lost
                    ? 'Annonces de perte'
                    : 'Annonces d’objets trouvés',
                style: AppText.h1,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _TypeTab(
                      label: 'Perdus',
                      selected: _type == ItemType.lost,
                      color: AppColors.lost,
                      onTap: () => setState(() => _type = ItemType.lost),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TypeTab(
                      label: 'Trouvés',
                      selected: _type == ItemType.found,
                      color: AppColors.found,
                      onTap: () => setState(() => _type = ItemType.found),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _search,
                onChanged: _onSearch,
                decoration: InputDecoration(
                  hintText: 'Rechercher un titre, un lieu…',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 12, right: 8),
                    child: AppIcon('magnifer-linear', size: 18),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 0),
                ),
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 8),
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
              const SizedBox(height: 16),
              catalog.when(
                loading: () => const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => _Message(
                  title: 'Chargement impossible',
                  body: 'Le serveur ne répond pas. Vérifiez la connexion puis réessayez.',
                  action: 'Réessayer',
                  onTap: () => ref.invalidate(catalogProvider(_catalogQuery)),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return _Message(
                      title: 'Aucune annonce',
                      body: _query.isEmpty && _category == null && _status == null
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
                          onTap: () => context.push(AppRoutes.itemDetail(item.id)),
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
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: item.imageUrl == null
                      ? ColoredBox(
                          color: AppColors.background,
                          child: AppIcon(
                            'box-linear',
                            color: item.type == ItemType.lost
                                ? AppColors.lost
                                : AppColors.found,
                          ),
                        )
                      : Image.network(
                          item.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: AppColors.background,
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: AppText.bodyStrong,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.place.isEmpty ? item.category.label : item.place,
                      style: AppText.tiny.copyWith(color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        StatusPill(type: item.type, compact: true),
                        const SizedBox(width: 8),
                        Text(
                          '$dateLabel · ${item.status.label}',
                          style: AppText.tiny.copyWith(color: AppColors.textTertiary),
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

class _TypeTab extends StatelessWidget {
  const _TypeTab({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? color : AppColors.border),
        ),
        child: Text(
          label,
          style: AppText.label.copyWith(
            color: selected
                ? (color == AppColors.found ? AppColors.mintDark : Colors.white)
                : AppColors.textSecondary,
          ),
        ),
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
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) => children[index],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: AppText.tiny.copyWith(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
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
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: AppIcon(icon, size: 20),
        ),
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
          Text(title, style: AppText.h2, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            body,
            style: AppText.body.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onTap, child: Text(action)),
        ],
      ),
    );
  }
}
