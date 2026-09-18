/// Centralized API Constants for PayFlow Mobile Application.
class ApiConstants {
  ApiConstants._();

  /// Development base URL tailored for platform:
  /// - Android Emulator (via adb reverse tcp:3000 tcp:3000): http://127.0.0.1:3000
  /// - Web / iOS / Desktop: http://127.0.0.1:3000
  static String get baseUrl {
    return 'http://127.0.0.1:3000';
  }
}
