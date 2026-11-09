import '../../../../data/models/item.dart';

/// Criteres de recherche/filtrage des objets.
class ObjectFilter {
  const ObjectFilter({
    this.type,
    this.category,
    this.status,
    this.searchQuery = '',
    this.startDate,
    this.endDate,
    this.latitude,
    this.longitude,
    this.radiusKm = 10,
    this.limit = 50,
    this.offset = 0,
  });

  final ItemType? type;
  final ItemCategory? category;
  final ItemStatus? status;
  final String searchQuery;
  final DateTime? startDate;
  final DateTime? endDate;

  final double? latitude;
  final double? longitude;
  final double radiusKm;

  final int limit;
  final int offset;

  ObjectFilter copyWith({
    ItemType? type,
    ItemCategory? category,
    ItemStatus? status,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
    double? latitude,
    double? longitude,
    double? radiusKm,
    int? limit,
    int? offset,
    bool clearType = false,
    bool clearCategory = false,
    bool clearStatus = false,
  }) {
    return ObjectFilter(
      type: clearType ? null : (type ?? this.type),
      category: clearCategory ? null : (category ?? this.category),
      status: clearStatus ? null : (status ?? this.status),
      searchQuery: searchQuery ?? this.searchQuery,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusKm: radiusKm ?? this.radiusKm,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
    );
  }

  bool get hasActiveCriteria =>
      type != null ||
      category != null ||
      status != null ||
      searchQuery.isNotEmpty ||
      startDate != null ||
      endDate != null ||
      (latitude != null && longitude != null);

  Map<String, dynamic> toQueryParams() {
    final params = <String, dynamic>{};

    if (type != null) params['type'] = type!.apiValue;
    if (category != null) params['category'] = category!.apiValue;
    if (status != null) params['status'] = status!.apiValue;
    if (searchQuery.isNotEmpty) params['q'] = searchQuery;
    if (startDate != null) params['occurred_from'] = startDate!.toIso8601String();
    if (endDate != null) params['occurred_to'] = endDate!.toIso8601String();
    if (latitude != null && longitude != null) {
      params['with_location'] = 1;
    }

    params['per_page'] = limit;
    params['page'] = offset < limit ? 1 : (offset ~/ limit) + 1;

    return params;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ObjectFilter &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          category == other.category &&
          status == other.status &&
          searchQuery == other.searchQuery &&
          startDate == other.startDate &&
          endDate == other.endDate &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          radiusKm == other.radiusKm &&
          limit == other.limit &&
          offset == other.offset;

  @override
  int get hashCode => Object.hash(
        type,
        category,
        status,
        searchQuery,
        startDate,
        endDate,
        latitude,
        longitude,
        radiusKm,
        limit,
        offset,
      );
}

/// Parametres de recherche geographique.
class NearbySearchParams {
  const NearbySearchParams({
    required this.latitude,
    required this.longitude,
    this.radiusKm = 10,
    this.type,
  });

  final double latitude;
  final double longitude;
  final double radiusKm;
  final ItemType? type;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NearbySearchParams &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          radiusKm == other.radiusKm &&
          type == other.type;

  @override
  int get hashCode => Object.hash(latitude, longitude, radiusKm, type);
}
