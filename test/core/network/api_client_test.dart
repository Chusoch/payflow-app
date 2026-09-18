import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:payflow/core/config/env.dart';
import 'package:payflow/core/network/api_client.dart';

void main() {
  group('ApiClient Unit Tests', () {
    test('post sends JSON body and headers to resolved baseUrl uri', () async {
      late Uri capturedUri;
      late Map<String, String> capturedHeaders;
      late String capturedBody;

      final mockHttp = MockClient((request) async {
        capturedUri = request.url;
        capturedHeaders = request.headers;
        capturedBody = request.body;
        return http.Response('{"status":"success"}', 200);
      });

      final client = ApiClient(
        baseUrl: 'https://api.payflow.app',
        httpClient: mockHttp,
      );

      final response = await client.post(
        '/v1/payments/paystack/initialize',
        body: {'amount_in_kobo': 50000},
      );

      expect(response.statusCode, equals(200));
      expect(capturedUri.toString(), equals('https://api.payflow.app/v1/payments/paystack/initialize'));
      expect(capturedHeaders['Content-Type'], equals('application/json'));
      expect(capturedBody, contains('50000'));
    });

    test('get appends query and handles baseUrl trailing slashes', () async {
      late Uri capturedUri;

      final mockHttp = MockClient((request) async {
        capturedUri = request.url;
        return http.Response('{"data":{}}', 200);
      });

      final client = ApiClient(
        baseUrl: 'https://api.payflow.app/',
        httpClient: mockHttp,
      );

      final response = await client.get('/v1/payments/paystack/verify/REF-123');

      expect(response.statusCode, equals(200));
      expect(capturedUri.toString(), equals('https://api.payflow.app/v1/payments/paystack/verify/REF-123'));
    });

    test('handles baseUrl with trailing dot (e.g. http://localhost:3000.) without FormatException', () async {
      late Uri capturedUri;

      final mockHttp = MockClient((request) async {
        capturedUri = request.url;
        return http.Response('{"status":true}', 200);
      });

      final client = ApiClient(
        baseUrl: 'http://localhost:3000.',
        httpClient: mockHttp,
      );

      final response = await client.post('/v1/payments/paystack/initialize', body: {});
      expect(response.statusCode, equals(200));
      expect(capturedUri.toString(), equals('http://localhost:3000/v1/payments/paystack/initialize'));
      expect(capturedUri.port, equals(3000));
    });

    test('Env.sanitizeUrl strips trailing dots and slashes safely', () {
      expect(Env.sanitizeUrl('http://localhost:3000.'), equals('http://localhost:3000'));
      expect(Env.sanitizeUrl('http://localhost:3000./'), equals('http://localhost:3000'));
      expect(Env.sanitizeUrl('http://localhost:3000/'), equals('http://localhost:3000'));
      expect(Env.sanitizeUrl('  http://localhost:3000.  '), equals('http://localhost:3000'));
      expect(Env.sanitizeUrl('https://api.payflow.app'), equals('https://api.payflow.app'));
    });

    test('Env.sanitizeUrl maps localhost and 10.0.2.2 to 127.0.0.1 for Android emulator', () {
      expect(
        Env.sanitizeUrl('http://localhost:3000', isAndroidOverride: true),
        equals('http://127.0.0.1:3000'),
      );
      expect(
        Env.sanitizeUrl('http://127.0.0.1:3000', isAndroidOverride: true),
        equals('http://127.0.0.1:3000'),
      );
      expect(
        Env.sanitizeUrl('http://10.0.2.2:3000', isAndroidOverride: true),
        equals('http://127.0.0.1:3000'),
      );
      expect(
        Env.sanitizeUrl('http://localhost:3000/', isAndroidOverride: true),
        equals('http://127.0.0.1:3000'),
      );
      expect(
        Env.sanitizeUrl('localhost:3000', isAndroidOverride: true),
        equals('127.0.0.1:3000'),
      );
      expect(
        Env.sanitizeUrl('10.0.2.2:3000', isAndroidOverride: true),
        equals('127.0.0.1:3000'),
      );
      expect(
        Env.sanitizeUrl('http://localhost:3000', isAndroidOverride: false),
        equals('http://localhost:3000'),
      );
    });

    test('ApiClient.sanitizeBaseUrl delegates to Env.sanitizeUrl and defaultBaseUrl matches Env.baseUrl', () {
      expect(
        ApiClient.sanitizeBaseUrl('http://localhost:3000', isAndroidOverride: true),
        equals('http://127.0.0.1:3000'),
      );
      expect(ApiClient.defaultBaseUrl, equals(Env.baseUrl));
    });

    test('401 Unauthorized triggers automatic token refresh retry', () async {
      int requestCount = 0;
      final mockHttp = MockClient((request) async {
        requestCount++;
        if (requestCount == 1) {
          return http.Response('{"error":"Unauthorized"}', 401);
        }
        return http.Response('{"status":"success"}', 200);
      });

      final client = ApiClient(
        baseUrl: 'https://api.payflow.app',
        httpClient: mockHttp,
      );

      final response = await client.get('/v1/vtpass/data-plans?network=mtn');
      expect(requestCount, equals(2));
      expect(response.statusCode, equals(200));
    });

    test('fresh login: wallet funding POST and GET requests inject Bearer token uniformly', () async {
      final capturedHeaders = <String, Map<String, String>>{};

      final mockHttp = MockClient((request) async {
        capturedHeaders[request.url.path] = request.headers;
        return http.Response('{"status":true,"data":{"status":"success"}}', 200);
      });

      final client = ApiClient(
        baseUrl: 'https://api.payflow.app',
        httpClient: mockHttp,
        tokenProvider: ({bool forceRefresh = false}) async => 'fresh_live_jwt_token_123',
      );

      // 1. Dedicated virtual account (POST)
      final res1 = await client.post('/v1/payments/paystack/dedicated-account', body: {'amount_in_kobo': 500000});
      expect(res1.statusCode, equals(200));
      expect(capturedHeaders['/v1/payments/paystack/dedicated-account']?['Authorization'], equals('Bearer fresh_live_jwt_token_123'));

      // 2. Paystack Card Initialize (POST)
      final res2 = await client.post('/v1/payments/paystack/initialize', body: {'reference': 'CARD-1', 'amount_in_kobo': 500000});
      expect(res2.statusCode, equals(200));
      expect(capturedHeaders['/v1/payments/paystack/initialize']?['Authorization'], equals('Bearer fresh_live_jwt_token_123'));

      // 3. Paystack Payment Verification (GET)
      final res3 = await client.get('/v1/payments/paystack/verify/CARD-1');
      expect(res3.statusCode, equals(200));
      expect(capturedHeaders['/v1/payments/paystack/verify/CARD-1']?['Authorization'], equals('Bearer fresh_live_jwt_token_123'));
    });

    test('stale/expired session: 401 invokes forceRefresh:true and retries with new token', () async {
      int refreshCallCount = 0;
      int requestCount = 0;
      final sentTokens = <String?>[];

      final mockHttp = MockClient((request) async {
        requestCount++;
        sentTokens.add(request.headers['Authorization']);
        if (requestCount == 1) {
          // First attempt with stale/expired token returns 401
          return http.Response('{"error":"Unauthorized: Invalid, revoked, or expired token"}', 401);
        }
        return http.Response('{"status":true,"data":{"status":"success"}}', 200);
      });

      final client = ApiClient(
        baseUrl: 'https://api.payflow.app',
        httpClient: mockHttp,
        tokenProvider: ({bool forceRefresh = false}) async {
          if (forceRefresh) {
            refreshCallCount++;
            return 'brand_new_refreshed_jwt_token_456';
          }
          return 'stale_expired_jwt_token_123';
        },
      );

      final response = await client.post('/v1/payments/paystack/initialize', body: {'reference': 'CARD-2', 'amount_in_kobo': 200000});
      expect(response.statusCode, equals(200));
      expect(requestCount, equals(2));
      expect(refreshCallCount, equals(1));
      expect(sentTokens[0], equals('Bearer stale_expired_jwt_token_123'));
      expect(sentTokens[1], equals('Bearer brand_new_refreshed_jwt_token_456'));
    });

    test('missing user session: omitting Authorization header returns Missing or malformed error', () async {
      int requestCount = 0;

      final mockHttp = MockClient((request) async {
        requestCount++;
        if (!request.headers.containsKey('Authorization')) {
          return http.Response('{"error":"Unauthorized: Missing or malformed Authorization header"}', 401);
        }
        return http.Response('{"status":true}', 200);
      });

      final client = ApiClient(
        baseUrl: 'https://api.payflow.app',
        httpClient: mockHttp,
        tokenProvider: ({bool forceRefresh = false}) async => null, // e.g. currentUser is null
      );

      final response = await client.post('/v1/payments/paystack/dedicated-account', body: {'amount_in_kobo': 100000});
      // Both initial and retry attempts lacked Authorization header, reproducing the exact error
      expect(response.statusCode, equals(401));
      expect(requestCount, equals(2));
      expect(response.body, contains('Unauthorized: Missing or malformed Authorization header'));
    });
  });
}
