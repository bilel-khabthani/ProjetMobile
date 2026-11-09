import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
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
    final resolved =
        await LocationService.getAddressFromCoordinates(point.latitude, point.longitude);
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
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Choisir un emplacement'),
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
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                    boxShadow: AppShadows.raised,
                                  ),
                                  child: const Center(
                                    child: AppIcon(
                                      'map-point-bold',
                                      size: 20,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 3,
                                  height: 8,
                                  color: AppColors.primary,
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
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.primary,
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
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      boxShadow: AppShadows.raised,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.touch_app_outlined,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            'Touche la carte pour placer le point.',
                            style: AppText.tiny,
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
                Container(
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
                        child: const Center(
                          child: AppIcon(
                            'map-point-linear',
                            size: 19,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Emplacement choisi', style: AppText.tiny),
                            const SizedBox(height: 2),
                            Text(
                              _picked == null
                                  ? 'Aucun point sélectionné'
                                  : (_resolving
                                      ? 'Recherche de l\'adresse…'
                                      : (_label ?? _formatCoords(_picked!))),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.bodyStrong,
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
