import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../constants/api_constants.dart';

/// Global Environment Configuration for PayFlow Mobile Application.
///
/// Configurable via `--dart-define=BACKEND_API_BASE_URL=https://...`
class Env {
  Env._();

  static String? _overrideBackendApiBaseUrl;

  /// Allows unit and integration tests to configure backend URL programmatically.
  static void setBackendApiBaseUrlForTesting(String? url) {
    _overrideBackendApiBaseUrl = url != null ? sanitizeUrl(url) : null;
  }

  /// Default development base URL tailored by platform:
  /// - Android (via adb reverse tcp:3000 tcp:3000): http://127.0.0.1:3000
  /// - Web / iOS / Desktop: http://127.0.0.1:3000
  static String get baseUrl => ApiConstants.baseUrl;

  /// Base URL of the PayFlow Backend Server (e.g. `https://api.payflow.app` or ngrok URL).
  /// Defaults to empty string `''`, enabling offline mock mode by default.
  static String get backendApiBaseUrl =>
      sanitizeUrl(_overrideBackendApiBaseUrl ??
      const String.fromEnvironment(
        'BACKEND_API_BASE_URL',
        defaultValue: '',
      ));

  /// Returns true if backend API base URL is unset, operating in dev mock mode.
  static bool get isMockMode => backendApiBaseUrl.trim().isEmpty;

  /// Sanitizes base URL by trimming whitespace, trailing slashes, and accidental trailing dots.
  /// Automatically translates Android emulator loopback host (`localhost` / `10.0.2.2` -> `127.0.0.1`).
  static String sanitizeUrl(String url, {bool? isAndroidOverride}) {
    var cleaned = url.trim();
    while (cleaned.endsWith('/') || cleaned.endsWith('.')) {
      cleaned = cleaned.substring(0, cleaned.length - 1).trim();
    }
    final isAndroid = isAndroidOverride ?? (!kIsWeb && Platform.isAndroid);
    if (isAndroid && cleaned.isNotEmpty) {
      cleaned = cleaned
          .replaceFirst('://localhost', '://127.0.0.1')
          .replaceFirst('://10.0.2.2', '://127.0.0.1');
      if (cleaned.startsWith('localhost:')) {
        cleaned = '127.0.0.1:${cleaned.substring('localhost:'.length)}';
      } else if (cleaned.startsWith('10.0.2.2:')) {
        cleaned = '127.0.0.1:${cleaned.substring('10.0.2.2:'.length)}';
      }
    }
    return cleaned;
  }
}
