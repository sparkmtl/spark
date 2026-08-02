import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.fieldErrors});

  final String message;
  final int? statusCode;
  final Map<String, String>? fieldErrors;

  @override
  String toString() => message;
}

class OtpSentResult {
  const OtpSentResult({required this.message});

  final String message;
}

class LoginResult {
  const LoginResult({
    required this.accessToken,
    required this.expiresIn,
    required this.user,
  });

  final String accessToken;
  final int expiresIn;
  final Map<String, dynamic> user;
}

/// HTTP client for `/api/auth` endpoints.
class AuthApi {
  AuthApi({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _client;
  final String _baseUrl;

  Future<OtpSentResult> sendSignupOtp({
    required String name,
    required String email,
    required String password,
  }) async {
    final json = await _postJson('/api/auth/register/send-otp', {
      'name': name,
      'email': email,
      'password': password,
    });
    return OtpSentResult(message: json['message'] as String? ?? 'OTP sent');
  }

  Future<OtpSentResult> forgotPassword({required String email}) async {
    final json = await _postJson('/api/auth/forgot-password', {
      'email': email,
    });
    return OtpSentResult(message: json['message'] as String? ?? 'OTP sent');
  }

  Future<void> verifyOtp({
    required String email,
    required String otp,
    required String purpose,
  }) async {
    await _postJson('/api/auth/verify-otp', {
      'email': email,
      'otp': otp,
      'purpose': purpose,
    });
  }

  Future<void> completeRegister({required String email}) async {
    await _postJson(
      '/api/auth/register',
      {'email': email},
      successStatuses: const {200, 201},
    );
  }

  Future<void> resetPassword({
    required String email,
    required String password,
  }) async {
    await _postJson('/api/auth/reset-password', {
      'email': email,
      'password': password,
    });
  }

  Future<LoginResult> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    final json = await _postJson('/api/auth/login', {
      'usernameOrEmail': usernameOrEmail,
      'password': password,
    });
    return LoginResult(
      accessToken: json['accessToken'] as String? ?? '',
      expiresIn: (json['expiresIn'] as num?)?.toInt() ?? 0,
      user: json['user'] is Map<String, dynamic>
          ? json['user'] as Map<String, dynamic>
          : const {},
    );
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body, {
    Set<int> successStatuses = const {200},
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    late final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 45));
    } catch (e) {
      debugPrint('AuthApi request to $uri failed: $e');
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

    if (!successStatuses.contains(response.statusCode)) {
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
