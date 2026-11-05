enum ItemType { lost, found }

extension ItemTypeX on ItemType {
  String get apiValue => this == ItemType.lost ? 'LOST' : 'FOUND';

  String get label => this == ItemType.lost ? 'Objet perdu' : 'Objet trouvé';

  String get shortLabel => this == ItemType.lost ? 'PERDU' : 'TROUVÉ';
}

ItemType itemTypeFromApiValue(Object? value) {
  final normalized = value?.toString().toUpperCase();
  return normalized == 'FOUND' ? ItemType.found : ItemType.lost;
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

  String get apiValue => switch (this) {
    ItemCategory.bag => 'sac',
    ItemCategory.phone => 'telephone',
    ItemCategory.keys => 'cles',
    ItemCategory.documents => 'papiers',
    ItemCategory.clothing => 'vetement',
    ItemCategory.glasses => 'lunettes',
    ItemCategory.wallet => 'portefeuille',
    ItemCategory.other => 'autre',
  };
}

String itemCategoryToCode(ItemCategory category) => category.apiValue;

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

ItemCategory itemCategoryFromApiValue(Object? value) =>
    itemCategoryFromCode(value?.toString().toLowerCase());

enum ItemStatus { active, matched, recovered, closed }

extension ItemStatusX on ItemStatus {
  String get label => switch (this) {
    ItemStatus.active => 'Active',
    ItemStatus.matched => 'Correspondance',
    ItemStatus.recovered => 'Récupéré',
    ItemStatus.closed => 'Clôturée',
  };

  String get apiValue => switch (this) {
    ItemStatus.active => 'ACTIVE',
    ItemStatus.matched => 'MATCHED',
    ItemStatus.recovered => 'RECOVERED',
    ItemStatus.closed => 'CLOSED',
  };
}

ItemStatus itemStatusFromApiValue(Object? value) {
  final normalized = value?.toString().toUpperCase();
  return switch (normalized) {
    'MATCHED' => ItemStatus.matched,
    'RECOVERED' || 'RESOLVED' => ItemStatus.recovered,
    'CLOSED' => ItemStatus.closed,
    _ => ItemStatus.active,
  };
}

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
}
