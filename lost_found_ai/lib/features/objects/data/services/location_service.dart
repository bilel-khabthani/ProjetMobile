import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import '../models/models.dart';

/// Service for handling location and geolocation operations
class LocationService {
  /// Request location permission from user
  static Future<bool> requestLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (_) {
      return false;
    }
  }

  /// Check if location services are enabled
  static Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return false;
    }
  }

  /// Get current user location
  static Future<LocationData?> getCurrentLocation() async {
    try {
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) return null;

      final isEnabled = await isLocationServiceEnabled();
      if (!isEnabled) return null;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      // Try to get address from coordinates with timeout
      final address = await getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        placeLabel: address?.placeLabel ?? 'Position actuelle',
        placeName: address?.placeName,
        address: address?.address,
        city: address?.city,
        country: address?.country,
      );
    } catch (e) {
      // If reverse geocoding fails, return coordinates
      try {
        final position = await Geolocator.getLastKnownPosition();
        if (position != null) {
          return LocationData.fromCoordinates(
            position.latitude,
            position.longitude,
          );
        }
      } catch (_) {}
      return null;
    }
  }

  /// Get address from coordinates using reverse geocoding
  static Future<LocationData?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await geocoding.Geocoding()
          .placemarkFromCoordinates(latitude, longitude)
          .timeout(const Duration(seconds: 5));

      if (placemarks.isEmpty) {
        return LocationData.fromCoordinates(latitude, longitude);
      }

      final placemark = placemarks.first;
      final parts = <String>[];

      if (placemark.street != null && placemark.street!.isNotEmpty) {
        parts.add(placemark.street!);
      }
      if (placemark.locality != null && placemark.locality!.isNotEmpty) {
        parts.add(placemark.locality!);
      }

      final locality = placemark.locality ?? placemark.subAdministrativeArea;
      final adminArea = placemark.administrativeArea;
      final label = parts.isNotEmpty
          ? parts.join(', ')
          : (locality != null ? '$locality, ${adminArea ?? ''}' : '$latitude, $longitude');

      return LocationData(
        latitude: latitude,
        longitude: longitude,
        placeLabel: label.trim(),
        placeName: placemark.name ?? locality ?? adminArea,
        address: parts.join(', '),
        city: locality,
        country: placemark.country,
      );
    } catch (e) {
      return LocationData.fromCoordinates(latitude, longitude);
    }
  }

  /// Get coordinates from address
  static Future<LocationData?> getCoordinatesFromAddress(
    String address,
  ) async {
    try {
      final locations = await geocoding.Geocoding()
          .locationFromAddress(address)
          .timeout(const Duration(seconds: 5));

      if (locations.isEmpty) return null;

      final location = locations.first;

      return LocationData(
        latitude: location.latitude,
        longitude: location.longitude,
        placeLabel: address,
        placeName: address,
      );
    } catch (e) {
      return null;
    }
  }

  /// Calculate distance between two points in kilometers (Haversine formula)
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371.0; // Earth's radius in kilometers
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.asin(math.sqrt(a.clamp(0.0, 1.0)));
    return r * c;
  }

  static double _toRad(double deg) => deg * (math.pi / 180.0);
}
