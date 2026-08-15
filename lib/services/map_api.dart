import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/map_user_model.dart';
import 'api_config.dart';
import 'auth_api.dart';
import 'auth_session.dart';

/// Talks to the `/api/map` endpoints: sharing the current user's location
/// and fetching other users to render on the map.
class MapApi {
  MapApi({http.Client? client, String? baseUrl, AuthSession? session})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.baseUrl,
        _session = session ?? AuthSession.instance;

  final http.Client _client;
  final String _baseUrl;
  final AuthSession _session;

  Future<void> updateLocation({
    required double latitude,
    required double longitude,
  }) async {
    await _requestJson(
      'PUT',
      '/api/map/location',
      body: {'latitude': latitude, 'longitude': longitude},
    );
  }

  Future<List<MapUserModel>> getNearbyUsers() async {
    final json = await _requestJsonList('GET', '/api/map/users');
    return json
        .whereType<Map<String, dynamic>>()
        .map(MapUserModel.fromJson)
        .toList();
  }

  Future<List<dynamic>> _requestJsonList(String method, String path) async {
    final response = await _send(method, path);
    if (response.body.isEmpty) return const [];
    final decoded = jsonDecode(response.body);
    return decoded is List ? decoded : const [];
  }

  Future<Map<String, dynamic>> _requestJson(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _send(method, path, body: body);
    if (response.body.isEmpty) return const {};
    final decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic> ? decoded : const {};
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final token = _session.accessToken;
    if (token == null || token.isEmpty) {
      throw ApiException('Please log in again.');
    }

    final uri = Uri.parse('$_baseUrl$path');
    final headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
    if (body != null) {
      headers['Content-Type'] = 'application/json';
    }

    late final http.Response response;
    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) {
        request.body = jsonEncode(body);
      }
      final streamed = await _client.send(request).timeout(
            const Duration(seconds: 45),
          );
      response = await http.Response.fromStream(streamed);
    } catch (e) {
      debugPrint('MapApi $method $uri failed: $e');
      throw ApiException(
        'Cannot reach the server. Make sure spark-api is running on port 8081. '
        '(${e.runtimeType})',
      );
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      _session.clear();
      throw ApiException(
        'Session expired. Please log in again.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Request failed (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }

    return response;
  }
}
