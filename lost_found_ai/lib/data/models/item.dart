enum ItemType { lost, found }

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
}

enum ItemStatus { active, matched, recovered, closed }

extension ItemStatusX on ItemStatus {
  String get label => switch (this) {
    ItemStatus.active => 'Active',
    ItemStatus.matched => 'Correspondance',
    ItemStatus.recovered => 'Récupéré',
    ItemStatus.closed => 'Clôturée',
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
