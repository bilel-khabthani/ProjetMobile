import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Erreur renvoyee par l'API, avec le code HTTP pour permettre a l'appelant
/// de distinguer un 401 (session expiree) d'un 422 (regle de metier).
class ApiException implements Exception {
  ApiException(this.statusCode, this.message, [this.body]);

  final int statusCode;
  final String message;

  /// Corps JSON de la reponse d'erreur (code metier, details de validation).
  final Map<String, dynamic>? body;

  /// Premier message de validation Laravel, sinon le message general.
  String get userMessage {
    final errors = body?['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) return first.first.toString();
      if (first != null) return first.toString();
    }
    return message;
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Client HTTP minimal devant l'API Laravel.
///
/// L'adresse de base est injectable a la compilation :
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000/api
/// Ce qui evite de recompiler pour tester sur un autre poste ou sur un
/// appareil physique.
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = baseUrl ?? defaultBaseUrl;

  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// L'emulateur Android atteint la machine hote via 10.0.2.2, alors qu'un
  /// navigateur (web) doit utiliser localhost. Un `--dart-define` reste
  /// prioritaire pour cibler un poste distant ou un telephone physique.
  static String get defaultBaseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    if (kIsWeb) return 'http://localhost:8000/api';
    return 'http://10.0.2.2:8000/api';
  }

  final http.Client _client;

  final String baseUrl;

  static const String _tokenKey = 'lost_found_auth_token';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  /// Jeton Sanctum. L'ecriture est automatiquement persistee dans le stockage
  /// securise : l'utilisateur reste connecte apres redemarrage de l'app (EF-01).
  String? _token;

  String? get token => _token;

  set token(String? value) {
    _token = value;
    // Ecriture asynchrone fire-and-forget : ne bloque pas le chemin critique.
    if (value == null) {
      _storage.delete(key: _tokenKey);
    } else {
      _storage.write(key: _tokenKey, value: value);
    }
  }

  /// Recharge le jeton persiste au demarrage de l'application.
  Future<String?> restoreToken() async {
    try {
      _token = await _storage.read(key: _tokenKey);
    } catch (_) {
      _token = null;
    }
    return _token;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<dynamic> get(String path) async {
    final response = await _client
        .get(_uri(path), headers: _headers)
        .timeout(const Duration(seconds: 15));

    return _decode(response);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final response = await _client
        .post(_uri(path), headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));

    return _decode(response);
  }

  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final response = await _client
        .put(_uri(path), headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));

    return _decode(response);
  }

  Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    final response = await _client
        .patch(_uri(path), headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));

    return _decode(response);
  }

  Future<dynamic> delete(String path) async {
    final response = await _client
        .delete(_uri(path), headers: _headers)
        .timeout(const Duration(seconds: 15));

    return _decode(response);
  }

  /// Convertit la reponse JSON et leve une ApiException sur erreur.
  dynamic _decode(http.Response response) {
    final body = response.body.isEmpty ? null : jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    final message = body is Map<String, dynamic>
        ? (body['message']?.toString() ?? 'Erreur ${response.statusCode}')
        : 'Erreur ${response.statusCode}';

    throw ApiException(
      response.statusCode,
      message,
      body is Map<String, dynamic> ? body : null,
    );
  }

  void close() => _client.close();
}
