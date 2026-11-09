import 'object_model.dart';

class ObjectsStats {
  const ObjectsStats({
    required this.totalLostObjects,
    required this.totalFoundObjects,
    required this.activeAnnouncements,
    required this.recoveredAnnouncements,
    required this.recentObjects,
  });

  final int totalLostObjects;
  final int totalFoundObjects;
  final int activeAnnouncements;
  final int recoveredAnnouncements;
  final List<LostFoundObject> recentObjects;

  int get totalAnnouncements => totalLostObjects + totalFoundObjects;

  double get recoveryRatePercent {
    final total = totalAnnouncements;
    if (total == 0) return 0;
    return (recoveredAnnouncements / total) * 100;
  }

  double get activeRatePercent {
    final total = totalAnnouncements;
    if (total == 0) return 0;
    return (activeAnnouncements / total) * 100;
  }

  bool get isEmpty => totalAnnouncements == 0;

  ObjectsStats copyWith({
    int? totalLostObjects,
    int? totalFoundObjects,
    int? activeAnnouncements,
    int? recoveredAnnouncements,
    List<LostFoundObject>? recentObjects,
  }) {
    return ObjectsStats(
      totalLostObjects: totalLostObjects ?? this.totalLostObjects,
      totalFoundObjects: totalFoundObjects ?? this.totalFoundObjects,
      activeAnnouncements: activeAnnouncements ?? this.activeAnnouncements,
      recoveredAnnouncements: recoveredAnnouncements ?? this.recoveredAnnouncements,
      recentObjects: recentObjects ?? this.recentObjects,
    );
  }

  factory ObjectsStats.empty() {
    return const ObjectsStats(
      totalLostObjects: 0,
      totalFoundObjects: 0,
      activeAnnouncements: 0,
      recoveredAnnouncements: 0,
      recentObjects: [],
    );
  }

  factory ObjectsStats.fromJson(Map<String, dynamic> json) {
    final recentList = (json['recent_objects'] as List<dynamic>?) ?? [];
    return ObjectsStats(
      totalLostObjects: (json['total_lost'] as num?)?.toInt() ?? 0,
      totalFoundObjects: (json['total_found'] as num?)?.toInt() ?? 0,
      activeAnnouncements: (json['active_count'] as num?)?.toInt() ?? 0,
      recoveredAnnouncements: (json['resolved_count'] as num?)?.toInt() ?? 0,
      recentObjects: recentList
          .map((item) => LostFoundObject.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  String toString() =>
      'ObjectsStats(lost: $totalLostObjects, found: $totalFoundObjects, active: $activeAnnouncements)';
}

class MyObjectsStats {
  const MyObjectsStats({
    required this.myLostObjects,
    required this.myFoundObjects,
    required this.myActiveObjects,
    required this.myRecoveredObjects,
    required this.allObjects,
  });

  final int myLostObjects;
  final int myFoundObjects;
  final int myActiveObjects;
  final int myRecoveredObjects;
  final List<LostFoundObject> allObjects;

  int get totalObjects => myLostObjects + myFoundObjects;

  double get recoveryRatePercent {
    final total = totalObjects;
    if (total == 0) return 0;
    return (myRecoveredObjects / total) * 100;
  }

  bool get isEmpty => totalObjects == 0;

  MyObjectsStats copyWith({
    int? myLostObjects,
    int? myFoundObjects,
    int? myActiveObjects,
    int? myRecoveredObjects,
    List<LostFoundObject>? allObjects,
  }) {
    return MyObjectsStats(
      myLostObjects: myLostObjects ?? this.myLostObjects,
      myFoundObjects: myFoundObjects ?? this.myFoundObjects,
      myActiveObjects: myActiveObjects ?? this.myActiveObjects,
      myRecoveredObjects: myRecoveredObjects ?? this.myRecoveredObjects,
      allObjects: allObjects ?? this.allObjects,
    );
  }

  factory MyObjectsStats.empty() {
    return const MyObjectsStats(
      myLostObjects: 0,
      myFoundObjects: 0,
      myActiveObjects: 0,
      myRecoveredObjects: 0,
      allObjects: [],
    );
  }

  @override
  String toString() =>
      'MyObjectsStats(lost: $myLostObjects, found: $myFoundObjects, active: $myActiveObjects)';
}