import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/item.dart';
import '../../../../widgets/app_bottom_sheet.dart';
import '../../../../widgets/app_button.dart';

import '../../../../widgets/app_icon.dart';
import '../../../../widgets/app_reveal.dart';
import '../../../../widgets/photo_placeholder.dart';
import '../../../../widgets/skeleton.dart';
import '../../data/providers/objects_providers.dart';
import '../../data/services/location_service.dart';

typedef _MapFilters = ({
  ItemType? type,
  ItemCategory? category,
  bool useRadius,
  double radiusKm,
});

class ObjectsMapScreen extends ConsumerStatefulWidget {
  const ObjectsMapScreen({super.key});

  @override
  ConsumerState<ObjectsMapScreen> createState() => _ObjectsMapScreenState();
}

class _ObjectsMapScreenState extends ConsumerState<ObjectsMapScreen> {
  static const _fallbackCenter = LatLng(36.8065, 10.1815);

  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  ItemType? _typeFilter;
  ItemCategory? _categoryFilter;
  String _query = '';
  double? _radiusKm;
  LatLng? _userPosition;
  LostFoundObject? _selected;
  bool _locating = false;
  bool _mapReady = false;
  bool _didInitialFit = false;
  double _zoom = 12.5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _trySilentLocate());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  int get _activeFilterCount {
    var count = 0;
    if (_typeFilter != null) count++;
    if (_categoryFilter != null) count++;
    if (_radiusKm != null) count++;
    return count;
  }

  Future<void> _trySilentLocate() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return;
      }
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;
      final position = await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(accuracy: LocationAccuracy.medium),
      );
      if (!mounted) return;
      setState(() {
        _userPosition = LatLng(position.latitude, position.longitude);
      });
    } catch (_) {}
  }

  Future<bool> _locateUser({bool moveCamera = true}) async {
    if (_locating) return false;
    setState(() => _locating = true);
    try {
      final location = await LocationService.getCurrentLocation();
      if (!mounted) return false;
      if (location == null) {
        _showMessage('Localisation indisponible. Vérifiez les autorisations.');
        return false;
      }
      final point = LatLng(location.latitude, location.longitude);
      setState(() {
        _userPosition = point;
        _selected = null;
      });
      if (moveCamera && _mapReady) {
        _mapController.move(point, 15);
      }
      return true;
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  List<LostFoundObject> _filtered(List<LostFoundObject> all) {
    final query = _query.trim().toLowerCase();
    return all.where((object) {
      if (object.latitude == null || object.longitude == null) return false;
      if (_typeFilter != null && object.type != _typeFilter) return false;
      if (_categoryFilter != null && object.category != _categoryFilter) {
        return false;
      }
      if (query.isNotEmpty) {
        final haystack = [
          object.title,
          object.description,
          object.placeLabel,
          object.category.label,
        ].join(' ').toLowerCase();
        if (!haystack.contains(query)) return false;
      }
      if (_radiusKm != null && _userPosition != null) {
        final distance = LocationService.calculateDistance(
          _userPosition!.latitude,
          _userPosition!.longitude,
          object.latitude!,
          object.longitude!,
        );
        if (distance > _radiusKm!) return false;
      }
      return true;
    }).toList();
  }

  void _fitTo(List<LostFoundObject> items) {
    if (!_mapReady) return;
    final points = [
      for (final object in items) LatLng(object.latitude!, object.longitude!),
    ];
    if (points.isEmpty) return;
    if (points.length == 1) {
      _mapController.move(points.first, 15);
      return;
    }
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.fromLTRB(54, 170, 54, 250),
      ),
    );
  }

  Future<void> _openFilters() async {
    final result = await showAppBottomSheet<_MapFilters>(
      context: context,
      showHandle: false,
      semanticLabel: 'Filtres de la carte',
      builder: (_) => _FiltersSheet(
        type: _typeFilter,
        category: _categoryFilter,
        useRadius: _radiusKm != null,
        radiusKm: _radiusKm ?? 10,
      ),
    );
    if (result == null) return;

    if (result.useRadius && _userPosition == null) {
      final located = await _locateUser(moveCamera: false);
      if (!located) return;
    }

    setState(() {
      _typeFilter = result.type;
      _categoryFilter = result.category;
      _radiusKm = result.useRadius ? result.radiusKm : null;
      _selected = null;
      // Recenter the camera on the filtered results.
      _didInitialFit = false;
    });
  }

  void _resetFilters() {
    setState(() {
      _typeFilter = null;
      _categoryFilter = null;
      _radiusKm = null;
      _query = '';
      _searchController.clear();
      _selected = null;
      _didInitialFit = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final objectsAsync = ref.watch(allObjectsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Carte des objets', style: context.typography.titleLarge),
        actions: [
          IconButton(
            tooltip: 'Liste',
            icon: const Icon(Icons.view_list_rounded),
            onPressed: () => context.push(AppRoutes.objectsList),
          ),
          const SizedBox(width: AppSpacing.xs - 4),
        ],
      ),
      body: objectsAsync.when(
        loading: () =>
            const Center(child: SkeletonBox(width: 220, height: 220)),
        error: (error, _) => _MapError(
          message: error.toString(),
          onRetry: () => ref.invalidate(allObjectsProvider),
        ),
        data: (all) {
          final visible = _filtered(all);

          if (!_didInitialFit && visible.isNotEmpty) {
            _didInitialFit = true;
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _fitTo(visible),
            );
          }

          final center =
              _userPosition ??
              (visible.isNotEmpty
                  ? LatLng(visible.first.latitude!, visible.first.longitude!)
                  : _fallbackCenter);

          final groups = _group(visible);
          final selected = _selected;

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 12.5,
                  minZoom: 2,
                  maxZoom: 19,
                  onMapReady: () {
                    _mapReady = true;
                    if (visible.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => _fitTo(visible),
                      );
                    }
                  },
                  onTap: (_, _) => setState(() => _selected = null),
                  onPositionChanged: (camera, _) {
                    if ((camera.zoom - _zoom).abs() >= 0.75) {
                      setState(() => _zoom = camera.zoom);
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'fr.campus.lost_found_ai',
                    maxZoom: 19,
                  ),
                  if (_userPosition != null && _radiusKm != null)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: _userPosition!,
                          radius: _radiusKm! * 1000,
                          useRadiusInMeter: true,
                          color: context.colors.primary.withValues(alpha: 0.07),
                          borderColor: context.colors.primary.withValues(
                            alpha: 0.35,
                          ),
                          borderStrokeWidth: 1.5,
                        ),
                      ],
                    ),
                  if (_userPosition != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _userPosition!,
                          width: 48,
                          height: 48,
                          child: _UserDot(locating: _locating),
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      for (final group in groups)
                        if (group.length == 1)
                          _objectMarker(group.first, selected)
                        else
                          _clusterMarker(group),
                    ],
                  ),
                ],
              ),
              Positioned(
                top: 10,
                left: AppSpacing.sm,
                right: AppSpacing.sm,
                child: _MapTopBar(
                  controller: _searchController,
                  query: _query,
                  onQueryChanged: (value) => setState(() {
                    _query = value;
                    _selected = null;
                  }),
                  onClear: () {
                    _searchController.clear();
                    setState(() {
                      _query = '';
                      _selected = null;
                    });
                  },
                  onOpenFilters: _openFilters,
                  activeFilters: _activeFilterCount,
                ),
              ),
              Positioned(
                top: 74,
                left: AppSpacing.sm,
                child: _CountPill(count: visible.length),
              ),
              Positioned(
                right: AppSpacing.sm,
                bottom: selected != null ? 178 : 92,
                child: Column(
                  children: [
                    _MapControlButton(
                      icon: Icons.my_location_rounded,
                      tooltip: 'Ma position',
                      busy: _locating,
                      onTap: () => _locateUser(),
                    ),
                    const SizedBox(height: 10),
                    _MapControlButton(
                      icon: Icons.zoom_out_map_rounded,
                      tooltip: 'Tout afficher',
                      onTap: () => _fitTo(visible),
                    ),
                  ],
                ),
              ),
              if (selected != null)
                Positioned(
                  left: AppSpacing.sm,
                  right: AppSpacing.sm,
                  bottom: AppSpacing.lg,
                  child: AppReveal(
                    key: ValueKey(selected.id),
                    index: 0,
                    offset: const Offset(0, 10),
                    child: _SelectedCard(
                      object: selected,
                    distanceKm: _userPosition == null
                        ? null
                        : LocationService.calculateDistance(
                            _userPosition!.latitude,
                            _userPosition!.longitude,
                            selected.latitude!,
                            selected.longitude!,
                          ),
                    onClose: () => setState(() => _selected = null),
                    onOpen: () =>
                        context.push(AppRoutes.objectDetail(selected.id)),
                    onItinerary: () => _openItinerary(selected),
                  ),
                ),
              ),
              if (visible.isEmpty)
                Positioned(
                  left: AppSpacing.xl,
                  right: AppSpacing.xl,
                  top: 130,
                  child: _EmptyCard(
                    hasFilters: _activeFilterCount > 0 || _query.isNotEmpty,
                    onReset: _resetFilters,
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: context.colors.primary,
        foregroundColor: context.colors.onPrimary,
        onPressed: () => context.push(AppRoutes.objectAdd),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Future<void> _openItinerary(LostFoundObject object) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination='
      '${object.latitude},${object.longitude}',
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) _showMessage('Impossible d’ouvrir l’itinéraire.');
  }

  List<List<LostFoundObject>> _group(List<LostFoundObject> items) {
    if (_zoom >= 14) {
      return [
        for (final item in items) [item],
      ];
    }
    final cell = _zoom >= 12
        ? 0.02
        : _zoom >= 10
        ? 0.08
        : 0.35;
    final buckets = <String, List<LostFoundObject>>{};
    for (final item in items) {
      final key =
          '${(item.latitude! / cell).floor()}:${(item.longitude! / cell).floor()}';
      (buckets[key] ??= []).add(item);
    }
    return buckets.values.toList();
  }

  Marker _objectMarker(LostFoundObject object, LostFoundObject? selected) {
    final isLost = object.type == ItemType.lost;
    final color = isLost ? context.colors.primary : context.colors.tertiary;
    final onColor = isLost
        ? context.colors.onPrimary
        : context.colors.onTertiary;
    final isSelected = selected?.id == object.id;

    return Marker(
      point: LatLng(object.latitude!, object.longitude!),
      width: isSelected ? 52 : 44,
      height: isSelected ? 52 : 44,
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: () {
          setState(() => _selected = object);
          if (_mapReady) {
            _mapController.move(
              LatLng(object.latitude!, object.longitude!),
              _zoom < 14 ? 14 : _zoom,
            );
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isSelected ? 40 : 34,
              height: isSelected ? 40 : 34,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? context.colors.primary
                      : context.colors.surface,
                  width: isSelected ? 3 : 2.5,
                ),
              ),
              child: Center(
                child: AppIcon(
                  categoryIconName(object.category),
                  size: isSelected ? 19 : 16,
                  color: onColor,
                ),
              ),
            ),
            Container(
              width: 3,
              height: 7,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Marker _clusterMarker(List<LostFoundObject> group) {
    final latitude =
        group.fold<double>(0, (sum, item) => sum + item.latitude!) /
        group.length;
    final longitude =
        group.fold<double>(0, (sum, item) => sum + item.longitude!) /
        group.length;
    final point = LatLng(latitude, longitude);
    final lost = group.where((item) => item.type == ItemType.lost).length;
    final isMostlyLost = lost >= group.length ~/ 2;
    final color = isMostlyLost
        ? context.colors.primary
        : context.colors.tertiary;
    final onColor = isMostlyLost
        ? context.colors.onPrimary
        : context.colors.onTertiary;

    return Marker(
      point: point,
      width: 48,
      height: 48,
      child: GestureDetector(
        onTap: () =>
            _mapController.move(point, (_zoom + 2).clamp(3, 18).toDouble()),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: context.colors.surface,
              shape: BoxShape.circle,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7),
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(
                '${group.length}',
                style: context.typography.titleMedium?.copyWith(
                  color: onColor,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapTopBar extends StatelessWidget {
  const _MapTopBar({
    required this.controller,
    required this.query,
    required this.onQueryChanged,
    required this.onClear,
    required this.onOpenFilters,
    required this.activeFilters,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClear;
  final VoidCallback onOpenFilters;
  final int activeFilters;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: context.colors.outlineVariant),
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                Icon(
                  Icons.search_rounded,
                  size: 21,
                  color: context.colors.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onQueryChanged,
                    textInputAction: TextInputAction.search,
                    style: context.typography.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Rechercher un objet, un lieu…',
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                  ),
                ),
                if (query.isNotEmpty)
                  IconButton(
                    tooltip: 'Effacer',
                    icon: const Icon(Icons.close_rounded, size: 19),
                    color: context.colors.onSurfaceVariant,
                    onPressed: onClear,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 50,
          height: 50,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: IconButton(
                  onPressed: onOpenFilters,
                  icon: const Icon(Icons.tune_rounded, size: 22),
                  style: IconButton.styleFrom(
                    backgroundColor: context.colors.primary,
                    foregroundColor: context.colors.onPrimary,
                    minimumSize: const Size(50, 50),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
              if (activeFilters > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: context.colors.tertiaryContainer,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.colors.primary,
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$activeFilters',
                      style: context.typography.labelSmall?.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: context.colors.onTertiaryContainer,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: Text(
        '$count objet${count > 1 ? 's' : ''} sur la carte',
        style: context.typography.labelMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: context.colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: busy ? null : onTap,
        icon: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            : Icon(icon, size: 22),
        style: IconButton.styleFrom(
          backgroundColor: context.colors.surface,
          foregroundColor: context.colors.primary,
          minimumSize: const Size(48, 48),
          shape: const CircleBorder(),
          side: BorderSide(color: context.colors.outlineVariant),
        ),
      ),
    );
  }
}

class _UserDot extends StatelessWidget {
  const _UserDot({required this.locating});

  final bool locating;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: context.colors.primary.withValues(alpha: 0.16),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: context.colors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: context.colors.surface, width: 2.5),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.hasFilters, required this.onReset});

  final bool hasFilters;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Icon(
            Icons.location_off_rounded,
            size: 34,
            color: context.colors.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Aucun objet sur la carte',
            style: context.typography.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            hasFilters
                ? 'Élargissez le rayon ou retirez des filtres.'
                : 'Les nouvelles annonces géolocalisées apparaîtront ici.',
            style: context.typography.bodySmall,
            textAlign: TextAlign.center,
          ),
          if (hasFilters) ...[
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: onReset,
              child: const Text('Réinitialiser les filtres'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SelectedCard extends StatelessWidget {
  const _SelectedCard({
    required this.object,
    required this.distanceKm,
    required this.onClose,
    required this.onOpen,
    required this.onItinerary,
  });

  final LostFoundObject object;
  final double? distanceKm;
  final VoidCallback onClose;
  final VoidCallback onOpen;
  final VoidCallback onItinerary;

  String _distanceLabel() {
    final distance = distanceKm;
    if (distance == null) return '';
    if (distance < 1) return '${(distance * 1000).round()} m';
    return '${distance.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final isLost = object.type == ItemType.lost;
    final color = isLost ? context.colors.primary : context.colors.tertiary;
    final soft = isLost
        ? context.colors.primaryContainer
        : context.colors.tertiaryContainer;
    final distance = _distanceLabel();

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.sm),
                child: SizedBox(
                  width: AppSpacing.huge + 16,
                  height: AppSpacing.huge + 16,
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
                    Text(
                      object.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.typography.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
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
                    if (distance.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.near_me_rounded,
                            size: 12,
                            color: context.colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'À $distance de vous',
                            style: context.typography.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Fermer',
                icon: const Icon(Icons.close_rounded),
                color: context.colors.onSurfaceVariant,
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: AppButton(label: 'Voir l’annonce', onPressed: onOpen),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: AppButton(
                  label: 'Itinéraire',
                  iconName: 'map-point-linear',
                  variant: AppButtonVariant.secondary,
                  onPressed: onItinerary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FiltersSheet extends StatefulWidget {
  const _FiltersSheet({
    required this.type,
    required this.category,
    required this.useRadius,
    required this.radiusKm,
  });

  final ItemType? type;
  final ItemCategory? category;
  final bool useRadius;
  final double radiusKm;

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  ItemType? _type;
  ItemCategory? _category;
  bool _useRadius = false;
  double _radiusKm = 10;

  @override
  void initState() {
    super.initState();
    _type = widget.type;
    _category = widget.category;
    _useRadius = widget.useRadius;
    _radiusKm = widget.radiusKm;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.sm,
          AppSpacing.xl,
          AppSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: context.colors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('Filtrer la carte', style: context.typography.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Affinez les annonces affichées autour de vous.',
                style: context.typography.bodySmall,
              ),
              const SizedBox(height: 18),
              Text('Type', style: context.typography.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  FilterChip(
                    label: const Text('Tous'),
                    selected: _type == null,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _type = null),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 14,
                    ),
                  ),
                  for (final type in ItemType.values)
                    FilterChip(
                      label: Text(type == ItemType.lost ? 'Perdus' : 'Trouvés'),
                      selected: _type == type,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _type = type),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 14,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Catégorie', style: context.typography.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  FilterChip(
                    label: const Text('Toutes'),
                    selected: _category == null,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _category = null),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 14,
                    ),
                  ),
                  for (final category in ItemCategory.values)
                    FilterChip(
                      label: Text(category.label),
                      selected: _category == category,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _category = category),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 14,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Autour de moi',
                          style: context.typography.titleMedium,
                        ),
                        Text(
                          _useRadius
                              ? 'Rayon de ${_radiusKm.round()} km'
                              : 'Afficher toutes les distances',
                          style: context.typography.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _useRadius,
                    onChanged: (value) => setState(() => _useRadius = value),
                  ),
                ],
              ),
              if (_useRadius) ...[
                Slider(
                  value: _radiusKm,
                  min: 1,
                  max: 50,
                  divisions: 49,
                  label: '${_radiusKm.round()} km',
                  onChanged: (value) => setState(() => _radiusKm = value),
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, (
                        type: null,
                        category: null,
                        useRadius: false,
                        radiusKm: 10.0,
                      )),
                      child: const Text('Réinitialiser'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppButton(
                      label: 'Appliquer',
                      onPressed: () => Navigator.pop(context, (
                        type: _type,
                        category: _category,
                        useRadius: _useRadius,
                        radiusKm: _radiusKm,
                      )),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapError extends StatelessWidget {
  const _MapError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 48, color: context.colors.error),
            const SizedBox(height: AppSpacing.md),
            Text('Carte indisponible', style: context.typography.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
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
