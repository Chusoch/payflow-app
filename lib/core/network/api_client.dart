import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../config/env.dart';

/// Centralized HTTP Network Client for PayFlow Backend Server calls.
///
/// Automatically fetches the active Firebase Auth ID token and injects
/// `Authorization: Bearer <token>` into request headers.
class ApiClient {
  /// Global hook indicating an authentication restoration or resolution is currently in progress.
  /// When non-null, requests requiring auth tokens will await this Future before sending without credentials.
  static Future<void>? authResolutionInProgress;

  final String baseUrl;
  final http.Client _httpClient;
  final Future<String?> Function({bool forceRefresh})? _tokenProvider;
  final FirebaseAuth? _firebaseAuth;
  final Future<void>? localAuthResolutionInProgress;

  FirebaseAuth get _auth => _firebaseAuth ?? FirebaseAuth.instance;

  ApiClient({
    String? baseUrl,
    http.Client? httpClient,
    Future<String?> Function({bool forceRefresh})? tokenProvider,
    FirebaseAuth? auth,
    Future<void>? authResolution,
  })  : baseUrl = sanitizeBaseUrl(baseUrl ?? (Env.backendApiBaseUrl.isNotEmpty ? Env.backendApiBaseUrl : Env.baseUrl)),
        _httpClient = httpClient ?? http.Client(),
        _tokenProvider = tokenProvider,
        _firebaseAuth = auth,
        localAuthResolutionInProgress = authResolution;

  Future<void>? get _activeAuthResolution =>
      localAuthResolutionInProgress ?? authResolutionInProgress;

  /// Retrieves the active Firebase Auth ID token if signed in.
  /// Attempts token retrieval with forceRefresh capability to prevent stale/expired tokens.
  /// Falls back to cached token if forceRefresh fails (e.g. offline environment).
  Future<String?> _getAuthToken({bool forceRefresh = false}) async {
    // 1. If an auth resolution is in progress, await it before evaluating credentials
    if (_activeAuthResolution != null) {
      try {
        await _activeAuthResolution!.timeout(const Duration(seconds: 5));
      } catch (_) {}
    }

    if (_tokenProvider != null) {
      return await _tokenProvider(forceRefresh: forceRefresh);
    }

    try {
      User? user;
      try {
        user = _auth.currentUser;
        if (user == null) {
          // If _auth.currentUser is null, check if an auth resolution is in progress
          if (_activeAuthResolution != null) {
            try {
              await _activeAuthResolution!.timeout(const Duration(seconds: 5));
            } catch (_) {}
            user = _auth.currentUser;
          }

          // Await authStateChanges().first before sending the request without credentials
          user ??= await _auth
              .authStateChanges()
              .first
              .timeout(const Duration(seconds: 3));
        }
      } catch (_) {}

      if (user != null) {
        return await user.getIdToken(forceRefresh);
      }
    } catch (_) {
      if (forceRefresh) {
        try {
          final user = _auth.currentUser;
          if (user != null) {
            return await user.getIdToken(false);
          }
        } catch (_) {}
      }
    }
    return null;
  }

  String? _explicitToken;

  /// Sets or clears the Bearer authorization token used for API requests.
  void setToken(String? token) {
    if (token != null && (token.startsWith('mock_') || token.split('.').length != 3)) {
      _explicitToken = null;
      return;
    }
    _explicitToken = token;
  }

  /// Gets the currently configured authorization token.
  String? get currentToken => _explicitToken;

  /// Builds authorization headers merging default headers and Bearer token.
  Future<Map<String, String>> _buildHeaders(Map<String, String>? customHeaders, {bool forceRefresh = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (customHeaders != null) ...customHeaders,
    };

    final token = _explicitToken ?? await _getAuthToken(forceRefresh: forceRefresh);
    if (token != null && token.isNotEmpty) {
      // ignore: avoid_print
      print('🔑 [PayFlow ApiClient] Active Token: Bearer $token');
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  /// Default API base URL for PayFlow development.
  /// Automatically resolves to `http://127.0.0.1:3000` on Android emulator (via adb reverse) and web/desktop.
  static String get defaultBaseUrl => Env.baseUrl;

  /// Sanitizes base URL by trimming whitespace, trailing slashes, and accidental trailing dots.
  /// Automatically translates Android emulator loopback host (`localhost` / `10.0.2.2` -> `127.0.0.1`).
  static String sanitizeBaseUrl(String url, {bool? isAndroidOverride}) {
    return Env.sanitizeUrl(url, isAndroidOverride: isAndroidOverride);
  }

  /// Resolves full Uri targeting backend API.
  Uri _resolveUri(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Uri.parse(path);
    }

    final cleanBase = sanitizeBaseUrl(baseUrl);
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$cleanBase$cleanPath');
  }

  /// Performs an HTTP GET request with auto-injected Auth Bearer header and 401 token refresh retry.
  Future<http.Response> get(String path, {Map<String, String>? headers}) async {
    final uri = _resolveUri(path);
    var requestHeaders = await _buildHeaders(headers, forceRefresh: false);
    var response = await _httpClient.get(uri, headers: requestHeaders);

    if (response.statusCode == 401) {
      // Force refresh ID token and retry request on 401 Unauthorized
      requestHeaders = await _buildHeaders(headers, forceRefresh: true);
      response = await _httpClient.get(uri, headers: requestHeaders);
    }

    return response;
  }

  /// Performs an HTTP POST request with auto-injected Auth Bearer header and 401 token refresh retry.
  Future<http.Response> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    final uri = _resolveUri(path);
    final encodedBody = body is String ? body : jsonEncode(body);
    var requestHeaders = await _buildHeaders(headers, forceRefresh: false);
    var response = await _httpClient.post(uri, headers: requestHeaders, body: encodedBody);

    if (response.statusCode == 401) {
      // Force refresh ID token and retry request on 401 Unauthorized
      requestHeaders = await _buildHeaders(headers, forceRefresh: true);
      response = await _httpClient.post(uri, headers: requestHeaders, body: encodedBody);
    }

    return response;
  }

  /// Performs an HTTP PUT request with auto-injected Auth Bearer header and 401 token refresh retry.
  Future<http.Response> put(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    final uri = _resolveUri(path);
    final encodedBody = body is String ? body : jsonEncode(body);
    var requestHeaders = await _buildHeaders(headers, forceRefresh: false);
    var response = await _httpClient.put(uri, headers: requestHeaders, body: encodedBody);

    if (response.statusCode == 401) {
      // Force refresh ID token and retry request on 401 Unauthorized
      requestHeaders = await _buildHeaders(headers, forceRefresh: true);
      response = await _httpClient.put(uri, headers: requestHeaders, body: encodedBody);
    }

    return response;
  }
}

/// Global shared ApiClient instance
ApiClient defaultApiClient = ApiClient();
