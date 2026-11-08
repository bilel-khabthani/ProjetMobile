import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/device_location.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/item.dart';
import '../../data/providers.dart';
import '../../widgets/status_pill.dart';
import 'location_picker_screen.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _controller = MapController();
  ItemType? _type;
  ItemCategory? _category;
  int? _days;
  Position? _position;
  bool _locationDenied = false;
  bool _didFit = false;
  String? _selectedId;

  static const _categories = [
    ItemCategory.bag,
    ItemCategory.phone,
    ItemCategory.keys,
    ItemCategory.wallet,
    ItemCategory.documents,
    ItemCategory.other,
  ];

  ItemCatalogQuery get _query {
    DateTime? from;
    if (_days != null) {
      final now = DateTime.now();
      from = DateTime(now.year, now.month, now.day).subtract(Duration(days: _days!));
    }
    return ItemCatalogQuery(
      type: _type,
      category: _category,
      withLocation: true,
      occurredAfter: from,
    );
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_locate);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    final position = await requestCurrentPosition();
    if (!mounted) return;
    setState(() {
      _position = position;
      _locationDenied = position == null;
    });
  }

  void _fit(List<Item> items) {
    if (_didFit) return;
    final points = <LatLng>[
      if (_position != null) LatLng(_position!.latitude, _position!.longitude),
      for (final item in items)
        if (item.hasCoordinates) LatLng(item.latitude!, item.longitude!),
    ];
    if (points.isEmpty) return;
    _didFit = true;
    if (points.length == 1) {
      _controller.move(points.first, 15);
      return;
    }
    _controller.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.fromLTRB(48, 120, 48, 160),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider(_query));
    ref.listen(catalogProvider(_query), (_, next) {
      next.whenData((items) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _fit(items);
        });
      });
    });

    final items = catalog.valueOrNull ?? const <Item>[];
    final located = <String, Item>{
      for (final item in items)
        if (item.hasCoordinates) item.id: item,
    };
    final selected = _selectedId == null ? null : located[_selectedId!];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: const LatLng(48.8566, 2.3522),
              initialZoom: 12,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'fr.campus.lost_found_ai',
              ),
              MarkerLayer(
                markers: [
                  if (_position != null)
                    Marker(
                      point: LatLng(_position!.latitude, _position!.longitude),
                      width: 22,
                      height: 22,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7BE0),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  for (final item in located.values)
                    Marker(
                      key: ValueKey(item.id),
                      point: LatLng(item.latitude!, item.longitude!),
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedId = item.id),
                        child: _Pin(
                          color: item.type == ItemType.lost
                              ? AppColors.lost
                              : AppColors.found,
                          selected: item.id == _selectedId,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        MapBackButton(
                          onTap: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go(AppRoutes.home);
                            }
                          },
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('Carte', style: AppText.h2.copyWith(fontSize: 20)),
                        ),
                        _TopAction(
                          label: 'Annonces',
                          onTap: () => context.push(AppRoutes.objects),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _ChipRow([
                      _Chip(
                        label: 'Tous',
                        selected: _type == null,
                        onTap: () => setState(() {
                          _type = null;
                          _didFit = false;
                          _selectedId = null;
                        }),
                      ),
                      _Chip(
                        label: 'Perdus',
                        selected: _type == ItemType.lost,
                        onTap: () => setState(() {
                          _type = ItemType.lost;
                          _didFit = false;
                          _selectedId = null;
                        }),
                      ),
                      _Chip(
                        label: 'Trouvés',
                        selected: _type == ItemType.found,
                        onTap: () => setState(() {
                          _type = ItemType.found;
                          _didFit = false;
                          _selectedId = null;
                        }),
                      ),
                      _Chip(
                        label: '7 jours',
                        selected: _days == 7,
                        onTap: () => setState(() {
                          _days = _days == 7 ? null : 7;
                          _didFit = false;
                        }),
                      ),
                      _Chip(
                        label: '30 jours',
                        selected: _days == 30,
                        onTap: () => setState(() {
                          _days = _days == 30 ? null : 30;
                          _didFit = false;
                        }),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    _ChipRow([
                      _Chip(
                        label: 'Toutes catégories',
                        selected: _category == null,
                        onTap: () => setState(() => _category = null),
                      ),
                      for (final category in _categories)
                        _Chip(
                          label: category.label,
                          selected: _category == category,
                          onTap: () => setState(() => _category = category),
                        ),
                    ]),
                    if (_locationDenied)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Position non autorisée. La carte reste utilisable.',
                          style: AppText.tiny.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                    if (catalog.hasError)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _TopAction(
                          label: 'Impossible de charger les annonces. Réessayer',
                          onTap: () => ref.invalidate(catalogProvider(_query)),
                        ),
                      )
                    else if (!catalog.isLoading && located.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Aucun objet géolocalisé pour ces filtres.',
                          style: AppText.tiny.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (catalog.isLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(color: AppColors.primary),
            ),
          if (selected != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _MarkerCard(
                item: selected,
                onClose: () => setState(() => _selectedId = null),
                onOpen: () => context.push(AppRoutes.itemDetail(selected.id)),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow(this.children);

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

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

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
          style: AppText.label.copyWith(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _TopAction extends StatelessWidget {
  const _TopAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(label, style: AppText.label.copyWith(color: AppColors.primary)),
        ),
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.color, required this.selected});

  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: selected ? 3 : 2),
      ),
      child: const Icon(Icons.place, color: Colors.white, size: 18),
    );
  }
}

class _MarkerCard extends StatelessWidget {
  const _MarkerCard({
    required this.item,
    required this.onClose,
    required this.onOpen,
  });

  final Item item;
  final VoidCallback onClose;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final date = item.occurredAt.toLocal();
    final dateLabel =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    return Material(
      color: AppColors.surface,
      elevation: 8,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 72,
                height: 72,
                child: item.imageUrl == null
                    ? ColoredBox(
                        color: item.type == ItemType.lost
                            ? AppColors.lostSoft
                            : AppColors.foundSoft,
                        child: Icon(
                          Icons.inventory_2_outlined,
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: AppText.bodyStrong,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: onClose,
                        icon: const Icon(Icons.close, size: 18),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  Text(
                    item.description,
                    style: AppText.tiny.copyWith(color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      StatusPill(type: item.type, compact: true),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$dateLabel · ${item.place.isEmpty ? 'Lieu non précisé' : item.place}',
                          style: AppText.tiny.copyWith(color: AppColors.textTertiary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: onOpen,
                      child: const Text('Voir le détail'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
