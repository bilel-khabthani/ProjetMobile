class LocationData {
  const LocationData({
    required this.latitude,
    required this.longitude,
    this.placeLabel,
    this.placeName,
    this.address,
    this.city,
    this.country,
  });

  final double latitude;
  final double longitude;
  final String? placeLabel;
  final String? placeName;
  final String? address;
  final String? city;
  final String? country;

  factory LocationData.fromCoordinates(double lat, double lon) {
    return LocationData(latitude: lat, longitude: lon);
  }

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      placeLabel: json['place_label'] as String?,
      placeName: json['place_name'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      country: json['country'] as String?,
    );
  }

  String get displayName {
    if (placeLabel != null && placeLabel!.isNotEmpty) {
      return placeLabel!;
    }
    if (placeName != null && placeName!.isNotEmpty) {
      return placeName!;
    }
    if (city != null && city!.isNotEmpty) {
      return city!;
    }
    return '$latitude, $longitude';
  }

  String get fullAddress {
    final parts = <String>[];
    if (address != null && address!.isNotEmpty) parts.add(address!);
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (country != null && country!.isNotEmpty) parts.add(country!);
    return parts.isEmpty ? displayName : parts.join(', ');
  }

  LocationData copyWith({
    double? latitude,
    double? longitude,
    String? placeLabel,
    String? placeName,
    String? address,
    String? city,
    String? country,
  }) {
    return LocationData(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      placeLabel: placeLabel ?? this.placeLabel,
      placeName: placeName ?? this.placeName,
      address: address ?? this.address,
      city: city ?? this.city,
      country: country ?? this.country,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      if (placeLabel != null) 'place_label': placeLabel,
      if (placeName != null) 'place_name': placeName,
      if (address != null) 'address': address,
      if (city != null) 'city': city,
      if (country != null) 'country': country,
    };
  }

  @override
  String toString() => 'LocationData($displayName)';
}

class MapMarker {
  const MapMarker({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.title,
    required this.type,
    required this.category,
    this.imageUrl,
    this.userName,
    this.distance,
  });

  final String id;
  final double latitude;
  final double longitude;
  final String title;
  final String type;
  final String category;
  final String? imageUrl;
  final String? userName;
  final double? distance;

  int get markerColorArgb {
    return type == 'LOST' ? 0xFFF4693C : 0xFF2FB57C;
  }

  String get displayInfo {
    final parts = <String>[title];
    if (userName != null) parts.add('par $userName');
    if (distance != null && distance! > 0) {
      parts.add('à ${distance!.toStringAsFixed(1)} km');
    }
    return parts.join(' ');
  }

  @override
  String toString() => 'MapMarker($title at $latitude,$longitude)';
}

class NearbyObjectsResult {
  const NearbyObjectsResult({
    required this.objects,
    required this.centerLat,
    required this.centerLon,
    required this.radiusKm,
    required this.totalCount,
  });

  final List<dynamic> objects;
  final double centerLat;
  final double centerLon;
  final double radiusKm;
  final int totalCount;

  List<MapMarker> toMapMarkers() {
    return objects.map((obj) {
      return MapMarker(
        id: obj.id,
        latitude: obj.latitude ?? 0,
        longitude: obj.longitude ?? 0,
        title: obj.title,
        type: obj.type.apiValue.toUpperCase(),
        category: obj.category.label,
        imageUrl: obj.imageUrl,
        userName: obj.userName,
        distance: obj.distanceKm,
      );
    }).toList();
  }
}