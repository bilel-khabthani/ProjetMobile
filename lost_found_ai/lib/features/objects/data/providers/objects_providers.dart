import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../../core/app_config.dart';
import '../../../../data/models/item.dart';
import '../../../../data/providers.dart';
import '../models/object_filter.dart';
import '../models/object_model.dart';
import '../models/objects_stats.dart';
import '../repositories/objects_repository.dart';

export '../models/object_filter.dart';
export '../models/object_model.dart';
export '../models/objects_stats.dart';

final objectsRepositoryProvider = Provider<ObjectsRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return ObjectsRepository(client: client);
});

final objectsProvider = FutureProvider.family<List<LostFoundObject>, ObjectFilter>(
  (ref, filter) async {
    if (AppConfig.useMockData) {
      return [];
    }
    final repository = ref.watch(objectsRepositoryProvider);
    return repository.searchObjects(filter);
  },
);

final allObjectsProvider = FutureProvider<List<LostFoundObject>>((ref) async {
  if (AppConfig.useMockData) {
    return [];
  }
  final repository = ref.watch(objectsRepositoryProvider);
  return repository.fetchObjects();
});

final lostObjectsProvider = FutureProvider<List<LostFoundObject>>((ref) async {
  if (AppConfig.useMockData) {
    return [];
  }
  final repository = ref.watch(objectsRepositoryProvider);
  return repository.fetchObjects(type: ItemType.lost);
});

final foundObjectsProvider = FutureProvider<List<LostFoundObject>>((ref) async {
  if (AppConfig.useMockData) {
    return [];
  }
  final repository = ref.watch(objectsRepositoryProvider);
  return repository.fetchObjects(type: ItemType.found);
});

final objectDetailProvider =
    FutureProvider.family<LostFoundObject, String>((ref, id) async {
  if (AppConfig.useMockData) {
    return LostFoundObject(
      id: id,
      userId: 1,
      type: ItemType.lost,
      category: ItemCategory.phone,
      title: 'Demo Object',
      description: 'This is a demo object',
      status: ItemStatus.active,
      latitude: 48.8566,
      longitude: 2.3522,
      placeLabel: 'Paris',
      occurredAt: DateTime.now(),
    );
  }
  final repository = ref.watch(objectsRepositoryProvider);
  return repository.fetchObject(id);
});

final myObjectsProvider = FutureProvider<List<LostFoundObject>>((ref) async {
  if (AppConfig.useMockData) {
    return [];
  }
  final repository = ref.watch(objectsRepositoryProvider);
  return repository.fetchMyObjects();
});

final myObjectsByStatusProvider =
    FutureProvider.family<List<LostFoundObject>, ItemStatus>((ref, status) async {
  if (AppConfig.useMockData) {
    return [];
  }
  final allMyObjects = await ref.watch(myObjectsProvider.future);
  return allMyObjects.where((obj) => obj.status == status).toList();
});

final nearbyObjectsProvider =
    FutureProvider.family<List<LostFoundObject>, NearbySearchParams>(
  (ref, params) async {
    if (AppConfig.useMockData) {
      return [];
    }
    final repository = ref.watch(objectsRepositoryProvider);
    return repository.fetchNearbyObjects(
      latitude: params.latitude,
      longitude: params.longitude,
      radiusKm: params.radiusKm,
      type: params.type,
    );
  },
);

final objectsStatsProvider = FutureProvider<ObjectsStats>((ref) async {
  if (AppConfig.useMockData) {
    return ObjectsStats.empty();
  }
  final repository = ref.watch(objectsRepositoryProvider);
  return repository.fetchObjectsStats();
});

final myObjectsStatsProvider = FutureProvider<MyObjectsStats>((ref) async {
  if (AppConfig.useMockData) {
    return MyObjectsStats.empty();
  }
  final repository = ref.watch(objectsRepositoryProvider);
  return repository.fetchMyObjectsStats();
});

class ObjectFormNotifier extends StateNotifier<ObjectFormState> {
  ObjectFormNotifier(this._repository) : super(const ObjectFormState());

  final ObjectsRepository _repository;

  void setEditingObject(LostFoundObject object) {
    state = state.copyWith(editingObject: object, isEditing: true);
  }

  void clearForm() {
    state = const ObjectFormState();
  }

  Future<LostFoundObject?> createObject(
    ItemType type,
    ItemCategory category,
    String title,
    String description,
    String placeLabel,
    DateTime occurredAt,
    double? latitude,
    double? longitude,
    String? contactPhone,
    String? secretDetail,
    http.MultipartFile? image,
  ) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final object = await _repository.createObject(
        type: type,
        category: category,
        title: title,
        description: description,
        placeLabel: placeLabel,
        occurredAt: occurredAt,
        latitude: latitude,
        longitude: longitude,
        contactPhone: contactPhone,
        secretDetail: secretDetail,
        image: image,
      );

      state = state.copyWith(isLoading: false, createdObject: object);
      return object;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<LostFoundObject?> updateObject(
    String id, {
    ItemType? type,
    ItemCategory? category,
    String? title,
    String? description,
    String? placeLabel,
    DateTime? occurredAt,
    double? latitude,
    double? longitude,
    String? contactPhone,
    String? secretDetail,
    bool removeImage = false,
    bool clearLocation = false,
    http.MultipartFile? image,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final object = await _repository.updateObject(
        id,
        type: type,
        category: category,
        title: title,
        description: description,
        placeLabel: placeLabel,
        occurredAt: occurredAt,
        latitude: latitude,
        longitude: longitude,
        contactPhone: contactPhone,
        secretDetail: secretDetail,
        removeImage: removeImage,
        clearLocation: clearLocation,
        image: image,
      );

      state = state.copyWith(
        isLoading: false,
        updatedObject: object,
        isEditing: false,
      );
      return object;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<bool> deleteObject(String id) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      await _repository.deleteObject(id);
      state = state.copyWith(isLoading: false, isDeleted: true);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<LostFoundObject?> resolveObject(String id) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final object = await _repository.resolveObject(id);
      state = state.copyWith(isLoading: false);
      return object;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }
}

class ObjectFormState {
  const ObjectFormState({
    this.editingObject,
    this.isEditing = false,
    this.isLoading = false,
    this.error,
    this.createdObject,
    this.updatedObject,
    this.isDeleted = false,
  });

  final LostFoundObject? editingObject;
  final bool isEditing;
  final bool isLoading;
  final String? error;
  final LostFoundObject? createdObject;
  final LostFoundObject? updatedObject;
  final bool isDeleted;

  ObjectFormState copyWith({
    LostFoundObject? editingObject,
    bool? isEditing,
    bool? isLoading,
    String? error,
    LostFoundObject? createdObject,
    LostFoundObject? updatedObject,
    bool? isDeleted,
  }) {
    return ObjectFormState(
      editingObject: editingObject ?? this.editingObject,
      isEditing: isEditing ?? this.isEditing,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      createdObject: createdObject ?? this.createdObject,
      updatedObject: updatedObject ?? this.updatedObject,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

final objectFormProvider =
    StateNotifierProvider<ObjectFormNotifier, ObjectFormState>((ref) {
  return ObjectFormNotifier(ref.watch(objectsRepositoryProvider));
});

/// Retry helper for object list/detail providers.
void invalidateObjectProviders(WidgetRef ref, {String? id}) {
  ref.invalidate(allObjectsProvider);
  ref.invalidate(lostObjectsProvider);
  ref.invalidate(foundObjectsProvider);
  ref.invalidate(objectsStatsProvider);
  ref.invalidate(myObjectsProvider);
  ref.invalidate(myObjectsStatsProvider);
  if (id != null) {
    ref.invalidate(objectDetailProvider(id));
  }
}
