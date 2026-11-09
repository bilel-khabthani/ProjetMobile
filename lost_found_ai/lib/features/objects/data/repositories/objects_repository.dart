import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../../../core/app_config.dart';
import '../../../../data/api_client.dart';
import '../../../../data/models/item.dart';
import '../models/object_filter.dart';
import '../models/object_model.dart';
import '../models/objects_stats.dart';

class ObjectsRepository {
  ObjectsRepository({ApiClient? client})
      : _client = client ?? ApiClient(baseUrl: AppConfig.apiBaseUrl);

  final ApiClient _client;

  List<dynamic> _extractList(dynamic response) {
    if (response is List) {
      return response;
    }
    if (response is Map) {
      if (response['data'] is List) {
        return response['data'] as List;
      }
      if (response['items'] is List) {
        return response['items'] as List;
      }
      if (response['objects'] is List) {
        return response['objects'] as List;
      }
    }
    return const [];
  }

  Future<List<LostFoundObject>> fetchObjects({
    ItemType? type,
    ItemCategory? category,
    ItemStatus? status,
    int limit = 50,
    int offset = 0,
  }) async {
    final params = <String, String>{};
    if (type != null) params['type'] = type.apiValue;
    if (category != null) params['category'] = category.apiValue;
    if (status != null) params['status'] = status.apiValue;
    params['limit'] = limit.toString();
    params['offset'] = offset.toString();

    final uri = Uri(path: '/objects', queryParameters: params);

    try {
      final res = await _client.get(uri.toString());
      final list = _extractList(res);
      return list.map((item) => LostFoundObject.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<LostFoundObject> fetchObject(String id) async {
    try {
      final json = await _client.get('/items/$id');
      if (json is Map<String, dynamic>) {
        final data = json['data'] is Map<String, dynamic> ? json['data'] as Map<String, dynamic> : json;
        return LostFoundObject.fromJson(data);
      }
      throw ApiException(500, 'Format de réponse invalide');
    } catch (e) {
      rethrow;
    }
  }

  Future<List<LostFoundObject>> fetchMyObjects() async {
    try {
      final res = await _client.get('/items/mine');
      final list = _extractList(res);
      return list.map((item) => LostFoundObject.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<LostFoundObject> createObject({
    required ItemType type,
    required ItemCategory category,
    required String title,
    required String description,
    required String placeLabel,
    required DateTime occurredAt,
    double? latitude,
    double? longitude,
    String? contactPhone,
    String? secretDetail,
    http.MultipartFile? image,
  }) async {
    try {
      if (image != null) {
        final uri = Uri.parse('${_client.baseUrl}/items');
        final request = http.MultipartRequest('POST', uri);

        request.headers['Authorization'] = 'Bearer ${_client.token}';
        request.headers['Accept'] = 'application/json';

        request.fields['type'] = type.apiValue;
        request.fields['category'] = category.apiValue;
        request.fields['title'] = title;
        request.fields['description'] = description;
        request.fields['place_label'] = placeLabel;
        request.fields['occurred_at'] = occurredAt.toUtc().toIso8601String();
        if (latitude != null) request.fields['latitude'] = latitude.toString();
        if (longitude != null) request.fields['longitude'] = longitude.toString();
        if (contactPhone != null && contactPhone.isNotEmpty) {
          request.fields['contact_phone'] = contactPhone;
        }
        if (secretDetail != null && secretDetail.isNotEmpty) {
          request.fields['secret_detail'] = secretDetail;
        }

        request.files.add(image);

        final response = await request.send().timeout(const Duration(seconds: 30));
        final body = await response.stream.bytesToString();

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final json = jsonDecode(body) as Map<String, dynamic>;
          return LostFoundObject.fromJson(json);
        } else {
          final json = jsonDecode(body) as Map<String, dynamic>;
          final message = json['message']?.toString() ?? 'Erreur ${response.statusCode}';
          throw ApiException(response.statusCode, message);
        }
      } else {
        final payload = {
          'type': type.apiValue,
          'category': category.apiValue,
          'title': title,
          'description': description,
          'place_label': placeLabel,
          'occurred_at': occurredAt.toUtc().toIso8601String(),
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
          if (contactPhone != null && contactPhone.isNotEmpty) 'contact_phone': contactPhone,
          if (secretDetail != null && secretDetail.isNotEmpty) 'secret_detail': secretDetail,
        };

        final json = await _client.post('/items', payload) as Map<String, dynamic>;
        return LostFoundObject.fromJson(json);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<LostFoundObject> updateObject(
    String id, {
    ItemCategory? category,
    String? title,
    String? description,
    String? placeLabel,
    DateTime? occurredAt,
    double? latitude,
    double? longitude,
    String? contactPhone,
    String? secretDetail,
    http.MultipartFile? image,
  }) async {
    try {
      if (image != null) {
        final uri = Uri.parse('${_client.baseUrl}/items/$id');
        final request = http.MultipartRequest('POST', uri);

        request.headers['Authorization'] = 'Bearer ${_client.token}';
        request.headers['Accept'] = 'application/json';
        request.fields['_method'] = 'PUT';

        if (category != null) request.fields['category'] = category.apiValue;
        if (title != null) request.fields['title'] = title;
        if (description != null) request.fields['description'] = description;
        if (placeLabel != null) request.fields['place_label'] = placeLabel;
        if (occurredAt != null) request.fields['occurred_at'] = occurredAt.toUtc().toIso8601String();
        if (latitude != null) request.fields['latitude'] = latitude.toString();
        if (longitude != null) request.fields['longitude'] = longitude.toString();
        if (contactPhone != null) request.fields['contact_phone'] = contactPhone;
        if (secretDetail != null) request.fields['secret_detail'] = secretDetail;

        request.files.add(image);

        final response = await request.send().timeout(const Duration(seconds: 30));
        final body = await response.stream.bytesToString();

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final json = jsonDecode(body) as Map<String, dynamic>;
          return LostFoundObject.fromJson(json);
        } else {
          final json = jsonDecode(body) as Map<String, dynamic>;
          final message = json['message']?.toString() ?? 'Erreur ${response.statusCode}';
          throw ApiException(response.statusCode, message);
        }
      } else {
        final payload = <String, dynamic>{};
        if (category != null) payload['category'] = category.apiValue;
        if (title != null) payload['title'] = title;
        if (description != null) payload['description'] = description;
        if (placeLabel != null) payload['place_label'] = placeLabel;
        if (occurredAt != null) payload['occurred_at'] = occurredAt.toUtc().toIso8601String();
        if (latitude != null) payload['latitude'] = latitude;
        if (longitude != null) payload['longitude'] = longitude;
        if (contactPhone != null) payload['contact_phone'] = contactPhone;
        if (secretDetail != null) payload['secret_detail'] = secretDetail;

        final json = await _client.put('/items/$id', payload) as Map<String, dynamic>;
        return LostFoundObject.fromJson(json);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteObject(String id) async {
    try {
      await _client.delete('/items/$id');
    } catch (e) {
      rethrow;
    }
  }

  Future<LostFoundObject> resolveObject(String id) async {
    try {
      final json = await _client.patch('/items/$id/resolve', {}) as Map<String, dynamic>;
      final item = json['item'] as Map<String, dynamic>?;
      if (item != null) {
        return LostFoundObject.fromJson(item);
      }
      return LostFoundObject.fromJson(json);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<LostFoundObject>> fetchNearbyObjects({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
    ItemType? type,
  }) async {
    try {
      final params = <String, String>{
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'radius_km': radiusKm.toString(),
      };
      if (type != null) params['type'] = type.apiValue;

      final queryString = params.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');
      final path = '/items/nearby?$queryString';

      final json = await _client.get(path);
      final list = _extractList(json);
      return list.map((item) => LostFoundObject.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<LostFoundObject>> fetchNearbyFound() async {
    try {
      final json = await _client.get('/items/nearby-found');
      final list = _extractList(json);
      return list.map((item) => LostFoundObject.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<LostFoundObject>> searchObjects(ObjectFilter filter) async {
    try {
      final params = <String, String>{};
      for (final entry in filter.toQueryParams().entries) {
        if (entry.value != null && entry.value.toString().isNotEmpty) {
          params[entry.key] = entry.value.toString();
        }
      }
      final uri = Uri(path: '/objects', queryParameters: params);

      final json = await _client.get(uri.toString());
      final list = _extractList(json);
      return list.map((item) => LostFoundObject.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<ObjectsStats> fetchObjectsStats() async {
    try {
      final json = await _client.get('/objects/statistics') as Map<String, dynamic>;
      return ObjectsStats.fromJson(json);
    } catch (_) {
      final allObjects = await fetchObjects();
      final totalLost = allObjects.where((o) => o.type == ItemType.lost).length;
      final totalFound = allObjects.where((o) => o.type == ItemType.found).length;
      final active = allObjects.where((o) => o.status == ItemStatus.active).length;
      final recovered = allObjects.where((o) => o.status == ItemStatus.recovered).length;
      final recent = allObjects.take(5).toList();

      return ObjectsStats(
        totalLostObjects: totalLost,
        totalFoundObjects: totalFound,
        activeAnnouncements: active,
        recoveredAnnouncements: recovered,
        recentObjects: recent,
      );
    }
  }

  Future<MyObjectsStats> fetchMyObjectsStats() async {
    try {
      final myObjects = await fetchMyObjects();

      final myLost = myObjects.where((o) => o.type == ItemType.lost).length;
      final myFound = myObjects.where((o) => o.type == ItemType.found).length;
      final myActive = myObjects.where((o) => o.status == ItemStatus.active).length;
      final myRecovered = myObjects.where((o) => o.status == ItemStatus.recovered).length;

      return MyObjectsStats(
        myLostObjects: myLost,
        myFoundObjects: myFound,
        myActiveObjects: myActive,
        myRecoveredObjects: myRecovered,
        allObjects: myObjects,
      );
    } catch (e) {
      rethrow;
    }
  }
}

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}