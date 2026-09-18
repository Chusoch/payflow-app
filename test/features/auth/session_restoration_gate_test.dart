import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:payflow/core/config/env.dart';
import 'package:payflow/core/network/api_client.dart';
import 'package:payflow/core/router/app_router.dart';
import 'package:payflow/core/theme/app_theme.dart';
import 'package:payflow/features/auth/models/auth_state.dart';
import 'package:payflow/features/auth/repositories/auth_repository.dart';
import 'package:payflow/features/auth/view_models/auth_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget buildTestApp({required ProviderContainer container}) {
  return UncontrolledProviderScope(
    container: container,
    child: Builder(
      builder: (context) {
        final router = container.read(appRouterProvider);
        return MaterialApp.router(
          theme: AppTheme.lightTheme(context),
          routerConfig: router,
        );
      },
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Session Restoration Gating & Missing Header Defense Tests', () {
    testWidgets(
      'App launch with stored authenticated flag gates navigation and prevents any API call with missing Authorization header until native restoration completes',
      (tester) async {
        // 1. Configure stored authenticated session in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('payflow_onboarding_completed', true);
        await prefs.setBool('payflow_is_authenticated', true);
        await prefs.setString('payflow_auth_phone', '+2348123456789');

        // Configure live backend environment
        Env.setBackendApiBaseUrlForTesting('https://api.payflow.app');
        addTearDown(() => Env.setBackendApiBaseUrlForTesting(null));

        // 2. Set up request monitoring
        final recordedRequests = <http.Request>[];
        final missingHeaderCalls = <String>[];
        bool isNativeRestorationComplete = false;

        final mockHttp = MockClient((request) async {
          recordedRequests.add(request);
          final authHeader = request.headers['Authorization'];
          if (authHeader == null || !authHeader.startsWith('Bearer ')) {
            missingHeaderCalls.add('${request.method} ${request.url.path}');
            return http.Response(
              '{"error":"Unauthorized: Missing or malformed Authorization header"}',
              401,
            );
          }
          return http.Response(
            '{"status":true,"walletBalance":5000000,"data":{}}',
            200,
          );
        });

        // 3. Set up custom token provider tied to native restoration lifecycle
        defaultApiClient = ApiClient(
          baseUrl: 'https://api.payflow.app',
          httpClient: mockHttp,
          tokenProvider: ({bool forceRefresh = false}) async {
            if (!isNativeRestorationComplete) {
              return null; // currentUser is null before restoration
            }
            return 'valid_restored_firebase_jwt_token_999';
          },
        );

        // 4. Simulate asynchronous native session restoration using a Completer
        final nativeSessionCompleter = Completer<void>();

        final container = ProviderContainer(
          overrides: [
            nativeAuthRestorerProvider.overrideWithValue(() => nativeSessionCompleter.future),
          ],
        );

        // 5. Launch the app
        await tester.pumpWidget(buildTestApp(container: container));

        // Pump past the standard 1500ms splash timeout while restoration is STILL pending
        await tester.pump(const Duration(milliseconds: 1600));

        final authStateDuringWait = container.read(authViewModelProvider);

        // Verify: UI is held in loading state and NOT yet marked authenticated
        expect(authStateDuringWait.isLoading, isTrue);
        expect(authStateDuringWait.status, isNot(equals(AuthStatus.authenticated)));

        // Verify: UI has NOT navigated to /home or rendered interactive home screen
        expect(find.text('Main Wallet Balance'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // CRITICAL CHECK: ZERO API calls fired with a missing Authorization header during the wait window!
        expect(
          missingHeaderCalls,
          isEmpty,
          reason: 'No API calls must fire before currentUser restoration completes',
        );

        // 6. Now signal that native platform session restoration has completed
        isNativeRestorationComplete = true;
        nativeSessionCompleter.complete();

        // Let the wait resolve, state update, and router redirect
        await tester.pumpAndSettle();

        final authStateAfterRestore = container.read(authViewModelProvider);

        // Verify: Now transitioning to authenticated state
        expect(authStateAfterRestore.isLoading, isFalse);
        expect(authStateAfterRestore.status, equals(AuthStatus.authenticated));

        // Verify: UI navigated to /home
        expect(find.text('Main Wallet Balance'), findsOneWidget);

        // Verify: All API calls that fired after restoration had valid Authorization headers
        expect(missingHeaderCalls, isEmpty);
        for (final req in recordedRequests) {
          expect(
            req.headers['Authorization'],
            equals('Bearer valid_restored_firebase_jwt_token_999'),
          );
        }
      },
    );

    testWidgets(
      'If local storage says a session exists, but native session restoration fails or resolves to null, local session is cleared and unauthenticated status is emitted',
      (tester) async {
        // 1. Configure stored authenticated session in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('payflow_onboarding_completed', true);
        await prefs.setBool('payflow_is_authenticated', true);
        await prefs.setString('payflow_auth_phone', '+2348123456789');

        // Configure live backend environment
        Env.setBackendApiBaseUrlForTesting('https://api.payflow.app');
        addTearDown(() => Env.setBackendApiBaseUrlForTesting(null));

        final repository = MockAuthRepository();
        await repository.init();
        expect(repository.hasActiveSession(), isTrue);

        // Native session restoration fails (e.g. timeout or null user)
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(repository),
            nativeAuthRestorerProvider.overrideWithValue(() => Future.error(Exception('Session expired'))),
          ],
        );

        // Launch app
        await tester.pumpWidget(buildTestApp(container: container));
        await tester.pump(const Duration(milliseconds: 1600));
        await tester.pumpAndSettle();

        final authState = container.read(authViewModelProvider);

        // Verify: Emits unauthenticated and isLoading is false
        expect(authState.isLoading, isFalse);
        expect(authState.status, equals(AuthStatus.unauthenticated));

        // Verify: Local flag was cleared via repository.clearSession()
        expect(repository.hasActiveSession(), isFalse);
        expect(repository.isAuthenticated(), isFalse);
        expect(prefs.getBool('payflow_is_authenticated'), isFalse);
      },
    );

    test(
      'ApiClient interceptor awaits active auth resolution before sending request without credentials',
      () async {
        final capturedHeaders = <String, String>{};
        final completer = Completer<void>();

        final mockHttp = MockClient((request) async {
          capturedHeaders.addAll(request.headers);
          return http.Response('{"status":true}', 200);
        });

        // Set auth resolution in progress
        ApiClient.authResolutionInProgress = completer.future;
        addTearDown(() => ApiClient.authResolutionInProgress = null);

        bool isTokenReady = false;
        final client = ApiClient(
          baseUrl: 'https://api.payflow.app',
          httpClient: mockHttp,
          tokenProvider: ({bool forceRefresh = false}) async {
            if (!isTokenReady) return null;
            return 'resolved_jwt_token_456';
          },
        );

        // Start get request without awaiting immediately
        final futureResponse = client.get('/v1/wallet/balance/me');

        // Small delay to ensure interceptor is waiting on authResolutionInProgress
        await Future.delayed(const Duration(milliseconds: 50));
        expect(capturedHeaders, isEmpty, reason: 'Request should not be dispatched while auth is resolving');

        // Complete auth resolution and mark token ready
        isTokenReady = true;
        completer.complete();

        final response = await futureResponse;
        expect(response.statusCode, equals(200));
        expect(capturedHeaders['Authorization'], equals('Bearer resolved_jwt_token_456'));
      },
    );
  });
}
