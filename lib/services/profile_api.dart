import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/profile_model.dart';
import 'api_config.dart';
import 'auth_api.dart';
import 'auth_session.dart';

class ProfileApi {
  ProfileApi({http.Client? client, String? baseUrl, AuthSession? session})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.baseUrl,
        _session = session ?? AuthSession.instance;

  final http.Client _client;
  final String _baseUrl;
  final AuthSession _session;

  Future<ProfileModel> getProfile() async {
    final json = await _requestJson('GET', '/api/profile');
    return _fromJson(json);
  }

  Future<ProfileModel> updateProfile(ProfileModel model) async {
    final body = <String, dynamic>{
      'name': model.name.trim(),
      'age': int.parse(model.age.trim()),
      'about': model.about.trim(),
      'gender': model.gender!.name,
      'intents': model.intents.map((i) => i.name).toList(),
    };

    // Always send the preference the user picked when that intent is active.
    if (model.intents.contains(LookingForIntent.date)) {
      body['dateLookingFor'] = model.dateLookingFor.name;
    }
    if (model.intents.contains(LookingForIntent.makeFriends)) {
      body['friendsLookingFor'] = model.friendsLookingFor.name;
    }

    debugPrint('ProfileApi PUT /api/profile body=$body');
    final json = await _requestJson('PUT', '/api/profile', body: body);
    return _fromJson(json);
  }

  ProfileModel _fromJson(Map<String, dynamic> json) {
    final intentsRaw = json['intents'];
    final intents = <LookingForIntent>{};
    if (intentsRaw is List) {
      for (final item in intentsRaw) {
        final parsed = _parseIntent('$item');
        if (parsed != null) intents.add(parsed);
      }
    }

    final ageValue = json['age'];
    return ProfileModel(
      name: json['name'] as String? ?? '',
      age: ageValue == null ? '' : '$ageValue',
      about: json['about'] as String? ?? '',
      gender: _parseProfileGender(json['gender'] as String?),
      intents: intents,
      dateLookingFor:
          _parseLookingForGender(json['dateLookingFor'] as String?) ??
              LookingForGender.any,
      friendsLookingFor:
          _parseLookingForGender(json['friendsLookingFor'] as String?) ??
              LookingForGender.any,
    );
  }

  ProfileGender? _parseProfileGender(String? raw) {
    if (raw == null) return null;
    for (final value in ProfileGender.values) {
      if (value.name == raw) return value;
    }
    return null;
  }

  LookingForGender? _parseLookingForGender(String? raw) {
    if (raw == null) return null;
    for (final value in LookingForGender.values) {
      if (value.name == raw) return value;
    }
    return null;
  }

  LookingForIntent? _parseIntent(String raw) {
    for (final value in LookingForIntent.values) {
      if (value.name == raw) return value;
    }
    return null;
  }

  Future<Map<String, dynamic>> _requestJson(
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
      final request = http.Request(method, uri)
        ..headers.addAll(headers);
      if (body != null) {
        request.body = jsonEncode(body);
      }
      final streamed = await _client.send(request).timeout(
            const Duration(seconds: 45),
          );
      response = await http.Response.fromStream(streamed);
    } catch (e) {
      debugPrint('ProfileApi $method $uri failed: $e');
      throw ApiException(
        'Cannot reach the server. Make sure spark-api is running on port 8081. '
        '(${e.runtimeType})',
      );
    }

    Map<String, dynamic> json = {};
    if (response.body.isNotEmpty) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        json = decoded;
      }
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      _session.clear();
      throw ApiException(
        json['message'] as String? ??
            'Session expired. Please log in again.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        json['message'] as String? ?? 'Request failed (${response.statusCode})',
        statusCode: response.statusCode,
        fieldErrors: _parseFieldErrors(json['errors']),
      );
    }

    return json;
  }

  Map<String, String>? _parseFieldErrors(Object? raw) {
    if (raw is! Map) return null;
    return raw.map((key, value) => MapEntry('$key', '$value'));
  }
}
