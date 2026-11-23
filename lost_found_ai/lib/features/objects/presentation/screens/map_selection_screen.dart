import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../widgets/app_button.dart';
import '../../../../widgets/app_icon.dart';
import '../../data/models/location_model.dart';
import '../../data/services/location_service.dart';

class MapSelectionScreen extends StatefulWidget {
  const MapSelectionScreen({super.key});

  @override
  State<MapSelectionScreen> createState() => _MapSelectionScreenState();
}

class _MapSelectionScreenState extends State<MapSelectionScreen> {
  static const _fallbackCenter = LatLng(36.8065, 10.1815);

  final MapController _mapController = MapController();
  LatLng? _picked;
  String? _label;
  bool _locating = false;
  bool _resolving = false;

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    final location = await LocationService.getCurrentLocation();
    if (!mounted) return;
    setState(() => _locating = false);
    if (location == null) {
      _showMessage('Localisation indisponible. Vérifie les permissions.');
      return;
    }
    final point = LatLng(location.latitude, location.longitude);
    setState(() {
      _picked = point;
      _label = location.displayName;
    });
    _mapController.move(point, 15.5);
  }

  Future<void> _onMapTap(TapPosition _, LatLng point) async {
    setState(() {
      _picked = point;
      _label = null;
      _resolving = true;
    });
    final resolved = await LocationService.getAddressFromCoordinates(
      point.latitude,
      point.longitude,
    );
    if (!mounted) return;
    setState(() {
      _resolving = false;
      _label = resolved?.displayName ?? _formatCoords(point);
    });
  }

  String _formatCoords(LatLng point) =>
      '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';

  void _confirm() {
    final point = _picked;
    if (point == null) return;
    context.pop(
      LocationData(
        latitude: point.latitude,
        longitude: point.longitude,
        placeLabel: _label ?? _formatCoords(point),
      ),
    );
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Choisir un emplacement',
          style: context.typography.titleLarge,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _fallbackCenter,
                    initialZoom: 13,
                    onTap: _onMapTap,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'fr.campus.lost_found_ai',
                    ),
                    if (_picked != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _picked!,
                            width: 48,
                            height: 48,
                            alignment: Alignment.topCenter,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: context.colors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: context.colors.surface,
                                      width: 3,
                                    ),
                                  ),
                                  child: Center(
                                    child: AppIcon(
                                      'map-point-bold',
                                      size: 20,
                                      color: context.colors.onPrimary,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 3,
                                  height: 8,
                                  color: context.colors.primary,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                Positioned(
                  top: AppSpacing.md,
                  left: AppSpacing.md,
                  child: FloatingActionButton.small(
                    heroTag: 'locate',
                    backgroundColor: context.colors.surfaceContainerLow,
                    foregroundColor: context.colors.primary,
                    onPressed: _locating ? null : _useCurrentLocation,
                    child: _locating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_rounded),
                  ),
                ),
                Positioned(
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  bottom: AppSpacing.md,
                  child: AppCard(
                    color: context.colors.surface.withValues(alpha: 0.95),
                    showBorder: false,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Icon(
                          Icons.touch_app_outlined,
                          size: 18,
                          color: context.colors.primary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            'Touche la carte pour placer le point.',
                            style: context.typography.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
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
                            'map-point-linear',
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
                            Text(
                              'Emplacement choisi',
                              style: context.typography.bodySmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _picked == null
                                  ? 'Aucun point sélectionné'
                                  : (_resolving
                                        ? 'Recherche de l\'adresse…'
                                        : (_label ?? _formatCoords(_picked!))),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.typography.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Confirmer l\'emplacement',
                  iconName: 'check-circle-bold',
                  expand: true,
                  onPressed: _picked == null || _resolving ? null : _confirm,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
