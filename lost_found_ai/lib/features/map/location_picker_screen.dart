import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/device_location.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_icon.dart';

/// Carte plein écran : l'utilisateur pose un point, puis confirme.
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key, this.initial});

  final LatLng? initial;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _controller = MapController();
  LatLng? _point;

  @override
  void initState() {
    super.initState();
    _point = widget.initial;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _useMyPosition() async {
    final position = await requestCurrentPosition();
    if (!mounted) return;
    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Localisation indisponible. Autorisez l’accès puis réessayez.',
          ),
        ),
      );
      return;
    }
    final point = LatLng(position.latitude, position.longitude);
    setState(() => _point = point);
    _controller.move(point, 16);
  }

  @override
  Widget build(BuildContext context) {
    final center = _point ?? widget.initial ?? const LatLng(48.8566, 2.3522);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text('Choisir le lieu', style: AppText.h2.copyWith(fontSize: 18)),
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: center,
                initialZoom: _point == null ? 12 : 16,
                onTap: (_, point) => setState(() => _point = point),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'fr.campus.lost_found_ai',
                ),
                if (_point != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _point!,
                        width: 42,
                        height: 42,
                        child: const _Pin(color: AppColors.primary),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _point == null
                        ? 'Touchez la carte pour placer l’objet.'
                        : '${_point!.latitude.toStringAsFixed(5)}, ${_point!.longitude.toStringAsFixed(5)}',
                    style: AppText.body.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _useMyPosition,
                          child: const Text('Ma position'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppButton(
                          label: 'Utiliser ce point',
                          onPressed: _point == null
                              ? null
                              : () => Navigator.of(context).pop(_point),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: const Icon(Icons.place, color: Colors.white, size: 22),
    );
  }
}

class MapBackButton extends StatelessWidget {
  const MapBackButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 44,
          height: 44,
          child: AppIcon('alt-arrow-left-linear', size: 20),
        ),
      ),
    );
  }
}
