import '../../core/app_config.dart';

enum ItemType { lost, found }

extension ItemTypeX on ItemType {
  /// API wire value used by ObjectsRepository (uppercase).
  String get apiValue => this == ItemType.lost ? 'lost' : 'found';

  /// Short display label for badges.
  String get shortLabel => this == ItemType.lost ? 'PERDU' : 'TROUVÉ';
}

/// Parse an API value like 'lost', 'found', 'LOST', 'FOUND'.
ItemType itemTypeFromApiValue(dynamic v) {
  final s = v?.toString().toLowerCase() ?? '';
  return s == 'found' ? ItemType.found : ItemType.lost;
}

enum ItemCategory {
  bag,
  phone,
  keys,
  documents,
  clothing,
  glasses,
  wallet,
  other,
}

extension ItemCategoryX on ItemCategory {
  String get label => switch (this) {
    ItemCategory.bag => 'Sac',
    ItemCategory.phone => 'Téléphone',
    ItemCategory.keys => 'Clés',
    ItemCategory.documents => 'Papiers',
    ItemCategory.clothing => 'Vêtement',
    ItemCategory.glasses => 'Lunettes',
    ItemCategory.wallet => 'Portefeuille',
    ItemCategory.other => 'Autre',
  };

  /// API wire value used by ObjectsRepository (French lowercase code).
  String get apiValue => itemCategoryToCode(this);
}

String itemCategoryToCode(ItemCategory category) => switch (category) {
  ItemCategory.bag => 'sac',
  ItemCategory.phone => 'telephone',
  ItemCategory.keys => 'cles',
  ItemCategory.documents => 'papiers',
  ItemCategory.clothing => 'vetement',
  ItemCategory.glasses => 'lunettes',
  ItemCategory.wallet => 'portefeuille',
  ItemCategory.other => 'autre',
};

ItemCategory itemCategoryFromCode(String? code) => switch (code) {
  'sac' => ItemCategory.bag,
  'telephone' => ItemCategory.phone,
  'cles' => ItemCategory.keys,
  'papiers' => ItemCategory.documents,
  'vetement' => ItemCategory.clothing,
  'lunettes' => ItemCategory.glasses,
  'portefeuille' => ItemCategory.wallet,
  _ => ItemCategory.other,
};

/// Parse API value (same codes as above).
ItemCategory itemCategoryFromApiValue(dynamic v) =>
    itemCategoryFromCode(v?.toString().toLowerCase());

enum ItemStatus { active, matched, disputed, recovered, closed }

extension ItemStatusX on ItemStatus {
  String get label => switch (this) {
    ItemStatus.active => 'Active',
    ItemStatus.matched => 'Correspondance',
    ItemStatus.disputed => 'Contesté',
    ItemStatus.recovered => 'Récupéré',
    ItemStatus.closed => 'Clôturée',
  };

  /// API wire value used by ObjectsRepository.
  String get apiValue => itemStatusToCode(this);
}

String itemStatusToCode(ItemStatus status) => switch (status) {
  ItemStatus.active => 'ACTIVE',
  ItemStatus.matched => 'MATCHED',
  ItemStatus.disputed => 'DISPUTED',
  ItemStatus.recovered => 'RECOVERED',
  ItemStatus.closed => 'CLOSED',
};

ItemStatus itemStatusFromCode(String? code) => switch (code) {
  'MATCHED' => ItemStatus.matched,
  'DISPUTED' => ItemStatus.disputed,
  'RECOVERED' => ItemStatus.recovered,
  'CLOSED' => ItemStatus.closed,
  _ => ItemStatus.active,
};

/// Parse API value (uppercase code).
ItemStatus itemStatusFromApiValue(dynamic v) =>
    itemStatusFromCode(v?.toString().toUpperCase());

class Item {
  const Item({
    required this.id,
    required this.type,
    required this.category,
    required this.title,
    required this.description,
    required this.place,
    required this.occurredAt,
    required this.distanceMeters,
    required this.status,
    this.latitude,
    this.longitude,
    this.imageUrl,
    this.ownerName,
    this.secretDetail,
    this.isMine = false,
  });

  final String id;
  final ItemType type;
  final ItemCategory category;
  final String title;
  final String description;
  final String place;
  final DateTime occurredAt;
  final int distanceMeters;
  final ItemStatus status;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
  final String? ownerName;
  final String? secretDetail;
  final bool isMine;

  bool get hasCoordinates => latitude != null && longitude != null;

  factory Item.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    final owner = json['owner_name'] as String? ??
        (user is Map ? user['name'] as String? : null);
    return Item(
      id: json['id']?.toString() ?? '',
      type: (json['type'] as String?)?.toUpperCase() == 'FOUND'
          ? ItemType.found
          : ItemType.lost,
      category: itemCategoryFromCode(json['category'] as String?),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      place: json['place_label'] as String? ?? '',
      occurredAt: DateTime.tryParse(json['occurred_at'] as String? ?? '') ??
          DateTime.now(),
      distanceMeters: (json['distance_meters'] as num?)?.toInt() ?? 0,
      status: itemStatusFromCode(json['status'] as String?),
      latitude: _asDouble(json['latitude']),
      longitude: _asDouble(json['longitude']),
      imageUrl: resolveItemImageUrl(json['image_url'] as String?),
      ownerName: owner,
      secretDetail: json['secret_detail'] as String?,
      isMine: json['is_mine'] == true,
    );
  }
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

/// Préfixe une URL relative renvoyée par Laravel (`/storage/...`).
///
/// On s'appuie sur [AppConfig.serverBaseUrl] pour que le Web utilise
/// `127.0.0.1` et l'émulateur Android `10.0.2.2`, sans URL codée en dur.
String? resolveItemImageUrl(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
  final origin = AppConfig.serverBaseUrl;
  return raw.startsWith('/') ? '$origin$raw' : '$origin/$raw';
}

/// Filtres du catalogue perdu / trouvé et de la carte.
class ItemCatalogQuery {
  const ItemCatalogQuery({
    this.type,
    this.category,
    this.status,
    this.search = '',
    this.withLocation = false,
    this.occurredAfter,
    this.sort = 'recent',
  });

  final ItemType? type;
  final ItemCategory? category;
  final ItemStatus? status;
  final String search;
  final bool withLocation;
  final DateTime? occurredAfter;
  final String sort;

  String toQuery({required int page}) {
    final params = <String, String>{
      'page': '$page',
      'per_page': '100',
      'sort': sort,
      if (type != null) 'type': type == ItemType.lost ? 'LOST' : 'FOUND',
      if (category != null) 'category': itemCategoryToCode(category!),
      if (status != null) 'status': itemStatusToCode(status!),
      if (search.trim().isNotEmpty) 'q': search.trim(),
      if (withLocation) 'with_location': '1',
      if (occurredAfter != null)
        'occurred_from': occurredAfter!.toUtc().toIso8601String(),
    };
    return params.entries
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');
  }

  @override
  bool operator ==(Object other) {
    return other is ItemCatalogQuery &&
        other.type == type &&
        other.category == category &&
        other.status == status &&
        other.search == search &&
        other.withLocation == withLocation &&
        other.sort == sort &&
        other.occurredAfter?.millisecondsSinceEpoch ==
            occurredAfter?.millisecondsSinceEpoch;
  }

  @override
  int get hashCode => Object.hash(
    type,
    category,
    status,
    search,
    withLocation,
    sort,
    occurredAfter?.millisecondsSinceEpoch,
  );
}
