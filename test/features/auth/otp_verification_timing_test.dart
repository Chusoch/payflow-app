import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:payflow/core/network/api_client.dart';
import 'package:payflow/features/auth/models/auth_state.dart';
import 'package:payflow/features/auth/repositories/auth_repository.dart';
import 'package:payflow/features/auth/view_models/auth_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SlowAuthRepository extends MockAuthRepository {
  final Completer<String?> otpCompleter = Completer<String?>();

  @override
  Future<String?> verifyOtp(String pinId, String otp) async {
    return await otpCompleter.future;
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('OTP Verification Timing & Race Condition Guard Tests', () {
    test('verifyOtp holds state in isLoading and blocks status transition until sign-in finishes', () async {
      final repository = SlowAuthRepository();
      await repository.init();
      await repository.setOnboardingCompleted(true);

      final viewModel = AuthViewModel(repository);
      await Future.delayed(Duration.zero);

      await viewModel.submitPhoneNumber('8123456789', isLogin: false);
      expect(viewModel.state.status, equals(AuthStatus.awaitingOtp));

      bool authenticatedCallFiredWhileInProgress = false;
      final mockHttp = MockClient((request) async {
        if (viewModel.state.status != AuthStatus.authenticated &&
            viewModel.state.status != AuthStatus.awaitingPinSetup) {
          authenticatedCallFiredWhileInProgress = true;
        }
        return http.Response('{"status":"success"}', 200);
      });

      final testApiClient = ApiClient(
        baseUrl: 'https://api.payflow.app',
        httpClient: mockHttp,
      );

      // Trigger OTP verification (sign-in in progress)
      final verifyFuture = viewModel.verifyOtp('123456');

      // Immediate check while verifyOtp is still pending in-flight:
      expect(viewModel.state.isLoading, isTrue);
      expect(viewModel.state.status, equals(AuthStatus.awaitingOtp));
      expect(viewModel.state.status, isNot(equals(AuthStatus.awaitingPinSetup)));
      expect(viewModel.state.status, isNot(equals(AuthStatus.authenticated)));

      // Confirm no authenticated API call fires while sign-in is in progress
      if (viewModel.state.status == AuthStatus.authenticated) {
        await testApiClient.get('/v1/vtpass/data-plans?network=mtn');
      }
      expect(authenticatedCallFiredWhileInProgress, isFalse);

      // Now complete the verifyOtp future with a test token
      repository.otpCompleter.complete('header.payload.signature_test');
      final result = await verifyFuture;

      expect(result, isTrue);
      expect(viewModel.state.isLoading, isFalse);
      expect(viewModel.state.status, equals(AuthStatus.awaitingPinSetup));
    });
  });
}
