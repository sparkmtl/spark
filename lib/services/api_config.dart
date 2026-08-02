import 'package:flutter/foundation.dart';

/// Base URL for spark-api.
abstract final class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:8081';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Android emulator → host machine
        return 'http://10.0.2.2:8081';
      default:
        return 'http://localhost:8081';
    }
  }
}
