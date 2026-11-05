import '../../../../core/app_config.dart';
import '../../../../data/models/item.dart';

/// Objet perdu/trouvé exposé au module "objets".
///
/// Réutilise les enums partagés [ItemType], [ItemCategory] et [ItemStatus]
/// definis dans `lib/data/models/item.dart`.
class LostFoundObject {
  const LostFoundObject({
    required this.id,
    required this.userId,
    required this.type,
    required this.category,
    required this.title,
    required this.description,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.placeLabel,
    required this.occurredAt,
    this.imagePath,
    this.contactPhone,
    this.secretDetail,
    this.userName,
    this.userTrustScore,
    this.distanceKm,
  });

  final String id;
  final int userId;
  final ItemType type;
  final ItemCategory category;
  final String title;
  final String description;
  final ItemStatus status;
  final double? latitude;
  final double? longitude;
  final String placeLabel;
  final DateTime occurredAt;
  final String? imagePath;
  final String? contactPhone;
  final String? secretDetail;

  final String? userName;
  final double? userTrustScore;
  final double? distanceKm;

  factory LostFoundObject.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return LostFoundObject(
      id: json['id']?.toString() ?? '',
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      type: itemTypeFromApiValue(json['type']),
      category: itemCategoryFromApiValue(json['category']),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: itemStatusFromApiValue(json['status']),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      placeLabel: json['place_label'] as String? ?? '',
      occurredAt:
          DateTime.tryParse(json['occurred_at']?.toString() ?? '') ??
          DateTime.now(),
      imagePath: (json['image_url'] as String?) ?? (json['image_path'] as String?),
      contactPhone: json['contact_phone'] as String?,
      secretDetail: json['secret_detail'] as String?,
      userName: user?['name'] as String?,
      userTrustScore: (user?['trust_score'] as num?)?.toDouble(),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.apiValue,
      'category': category.apiValue,
      'title': title,
      'description': description,
      'place_label': placeLabel,
      'occurred_at': occurredAt.toUtc().toIso8601String(),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (contactPhone != null && contactPhone!.isNotEmpty)
        'contact_phone': contactPhone,
      if (secretDetail != null && secretDetail!.isNotEmpty)
        'secret_detail': secretDetail,
    };
  }

  LostFoundObject copyWith({
    String? id,
    int? userId,
    ItemType? type,
    ItemCategory? category,
    String? title,
    String? description,
    ItemStatus? status,
    double? latitude,
    double? longitude,
    String? placeLabel,
    DateTime? occurredAt,
    String? imagePath,
    String? contactPhone,
    String? secretDetail,
    String? userName,
    double? userTrustScore,
    double? distanceKm,
  }) {
    return LostFoundObject(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      category: category ?? this.category,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      placeLabel: placeLabel ?? this.placeLabel,
      occurredAt: occurredAt ?? this.occurredAt,
      imagePath: imagePath ?? this.imagePath,
      contactPhone: contactPhone ?? this.contactPhone,
      secretDetail: secretDetail ?? this.secretDetail,
      userName: userName ?? this.userName,
      userTrustScore: userTrustScore ?? this.userTrustScore,
      distanceKm: distanceKm ?? this.distanceKm,
    );
  }

  bool isOwnedBy(String userId) => userId == this.userId.toString();

  bool canEdit(String userId) =>
      isOwnedBy(userId) && status == ItemStatus.active;

  bool canDelete(String userId) => isOwnedBy(userId);

  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(occurredAt);

    if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays}j';
    } else {
      return 'Le ${occurredAt.day}/${occurredAt.month}/${occurredAt.year}';
    }
  }

  String? get imageUrl {
    if (imagePath == null || imagePath!.isEmpty) return null;
    if (imagePath!.startsWith('http://') || imagePath!.startsWith('https://')) {
      return imagePath;
    }
    final cleanPath =
        imagePath!.startsWith('/') ? imagePath!.substring(1) : imagePath!;
    final storagePath =
        cleanPath.startsWith('storage/') ? cleanPath : 'storage/$cleanPath';
    return '${AppConfig.serverBaseUrl}/$storagePath';
  }

  @override
  String toString() =>
      'LostFoundObject(id: $id, type: ${type.name}, title: $title)';
}
