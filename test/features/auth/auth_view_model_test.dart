import 'package:flutter_test/flutter_test.dart';
import 'package:payflow/core/network/api_client.dart';
import 'package:payflow/features/auth/models/auth_state.dart';
import 'package:payflow/features/auth/repositories/auth_repository.dart';
import 'package:payflow/features/auth/view_models/auth_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late MockAuthRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = MockAuthRepository();
    await repository.init();
  });

  group('AuthViewModel - Foundation Authentication Tests', () {
    test('New user flow: Onboarding -> Phone -> OTP -> PIN -> Authenticated', () async {
      final viewModel = AuthViewModel(repository);
      await Future.delayed(Duration.zero);

      // Fresh install -> onboardingRequired
      expect(viewModel.state.status, equals(AuthStatus.onboardingRequired));

      // Complete onboarding -> unauthenticated
      await viewModel.completeOnboarding();
      expect(viewModel.state.status, equals(AuthStatus.unauthenticated));
      expect(viewModel.state.isOnboardingCompleted, isTrue);

      // Submit phone number for sign up -> awaitingOtp
      final phoneSent = await viewModel.submitPhoneNumber('8123456789', isLogin: false);
      expect(phoneSent, isTrue);
      expect(viewModel.state.status, equals(AuthStatus.awaitingOtp));
      expect(viewModel.state.phoneNumber, equals('8123456789'));

      // Verify OTP -> awaitingPinSetup
      final otpVerified = await viewModel.verifyOtp('123456');
      expect(otpVerified, isTrue);
      expect(viewModel.state.status, equals(AuthStatus.awaitingPinSetup));

      // Set Draft PIN -> awaitingPinConfirm
      viewModel.setDraftPin('1234');
      expect(viewModel.state.status, equals(AuthStatus.awaitingPinConfirm));
      expect(viewModel.state.draftPin, equals('1234'));

      // Confirm PIN -> awaitingProfileSetup
      final pinConfirmed = await viewModel.confirmPin('1234');
      expect(pinConfirmed, isTrue);
      expect(viewModel.state.status, equals(AuthStatus.awaitingProfileSetup));

      // Submit Profile -> authenticated (or awaitingBiometrics)
      final profileSaved = await viewModel.submitProfile(fullName: 'Ada Lovelace', email: 'ada@example.com');
      expect(profileSaved, isTrue);
      expect(
        viewModel.state.status == AuthStatus.authenticated ||
            viewModel.state.status == AuthStatus.awaitingBiometrics,
        isTrue,
      );
      expect(viewModel.state.fullName, equals('Ada Lovelace'));
      expect(viewModel.state.email, equals('ada@example.com'));
    });

    test('Returning user flow: Stored authenticated state restores authenticated status and user profile', () async {
      // Simulate stored active session with user profile name and token
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('payflow_onboarding_completed', true);
      await prefs.setBool('payflow_is_authenticated', true);
      await prefs.setString('payflow_auth_phone', '8123456789');
      await prefs.setString('payflow_user_fullname', 'Chukwuma Ugobueze');
      await prefs.setString('payflow_custom_token', 'eyJhbGciOi.eyJzdWIiOi.signature_8123456789');

      final viewModel = AuthViewModel(repository);
      await Future.delayed(Duration.zero);

      expect(viewModel.state.status, equals(AuthStatus.authenticated));
      expect(viewModel.state.phoneNumber, equals('8123456789'));
      expect(viewModel.state.fullName, equals('Chukwuma Ugobueze'));
      expect(viewModel.state.user, isNotNull);
      expect(viewModel.state.user?.fullName, equals('Chukwuma Ugobueze'));
      expect(viewModel.state.user?.firstName, equals('Chukwuma'));
      expect(viewModel.state.user?.lastName, equals('Ugobueze'));
      expect(defaultApiClient.currentToken, equals('eyJhbGciOi.eyJzdWIiOi.signature_8123456789'));
    });

    test('Stored invalid or mock token is rejected and clears session to navigate to login', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('payflow_onboarding_completed', true);
      await prefs.setBool('payflow_is_authenticated', true);
      await prefs.setString('payflow_auth_phone', '8123456789');
      await prefs.setString('payflow_custom_token', 'mock_custom_token_123456');

      final viewModel = AuthViewModel(repository);
      await Future.delayed(Duration.zero);

      expect(viewModel.state.status, equals(AuthStatus.unauthenticated));
      expect(defaultApiClient.currentToken, isNull);
    });

    test('UserModel correctly parses fullName, firstName, lastName, and fallback fields', () {
      final user = UserModel.fromJson({
        'phone': '+2348146357043',
        'fullName': 'Chukwuma Ugobueze',
        'email': 'chuma@example.com',
      });

      expect(user.fullName, equals('Chukwuma Ugobueze'));
      expect(user.firstName, equals('Chukwuma'));
      expect(user.lastName, equals('Ugobueze'));
      expect(user.phoneNumber, equals('+2348146357043'));
      expect(user.email, equals('chuma@example.com'));

      final singleNameUser = UserModel.fromJson({
        'name': 'Babajide',
      });
      expect(singleNameUser.fullName, equals('Babajide'));
      expect(singleNameUser.firstName, equals('Babajide'));
      expect(singleNameUser.lastName, isNull);

      final syntheticUser = UserModel.fromJson({
        'phone': '+2348146357043',
        'displayName': 'User +2348146357043',
      });
      expect(syntheticUser.fullName, isNull);
    });

    test('Login flow: Phone -> OTP -> awaitingPinLogin -> PIN login -> Authenticated', () async {
      await repository.setOnboardingCompleted(true);
      await repository.setupPin('1234');

      final viewModel = AuthViewModel(repository);
      await Future.delayed(Duration.zero);

      expect(viewModel.state.status, equals(AuthStatus.unauthenticated));

      // Submit phone for login
      final phoneSent = await viewModel.submitPhoneNumber('8123456789', isLogin: true);
      expect(phoneSent, isTrue);
      expect(viewModel.state.status, equals(AuthStatus.awaitingOtp));
      expect(viewModel.state.isLoginFlow, isTrue);

      // Verify OTP for login -> awaitingPinLogin
      final otpVerified = await viewModel.verifyOtp('123456');
      expect(otpVerified, isTrue);
      expect(viewModel.state.status, equals(AuthStatus.awaitingPinLogin));

      // Login with PIN -> authenticated
      final loggedIn = await viewModel.loginWithPin('1234');
      expect(loggedIn, isTrue);
      expect(viewModel.state.status, equals(AuthStatus.authenticated));
    });

    test('Invalid credentials: Invalid OTP and PIN fail cleanly', () async {
      await repository.setOnboardingCompleted(true);
      final viewModel = AuthViewModel(repository);
      await Future.delayed(Duration.zero);

      await viewModel.submitPhoneNumber('8123456789', isLogin: true);

      // Invalid OTP '000000'
      final invalidOtp = await viewModel.verifyOtp('000000');
      expect(invalidOtp, isFalse);
      expect(viewModel.state.errorMessage, contains('Invalid OTP'));
      expect(viewModel.state.status, equals(AuthStatus.awaitingOtp));

      // Valid OTP to advance to awaitingPinLogin
      await viewModel.verifyOtp('123456');
      expect(viewModel.state.status, equals(AuthStatus.awaitingPinLogin));

      // Invalid PIN '9999'
      final invalidPin = await viewModel.loginWithPin('9999');
      expect(invalidPin, isFalse);
      expect(viewModel.state.errorMessage, contains('Incorrect PIN'));
      expect(viewModel.state.status, equals(AuthStatus.awaitingPinLogin));
    });

    test('Logout flow: Authenticated -> logout -> unauthenticated', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('payflow_onboarding_completed', true);
      await prefs.setBool('payflow_is_authenticated', true);

      final viewModel = AuthViewModel(repository);
      await Future.delayed(Duration.zero);

      expect(viewModel.state.status, equals(AuthStatus.authenticated));

      // Logout
      await viewModel.logout();

      expect(viewModel.state.status, equals(AuthStatus.unauthenticated));
      expect(viewModel.state.phoneNumber, isNull);
      expect(viewModel.state.draftPin, isNull);
      expect(repository.isAuthenticated(), isFalse);
    });

    test('Biometric authentication sets authenticated status', () async {
      await repository.setOnboardingCompleted(true);
      final viewModel = AuthViewModel(repository);
      await Future.delayed(Duration.zero);

      final bioSuccess = await viewModel.loginWithBiometrics();
      expect(bioSuccess, isTrue);
      expect(viewModel.state.status, equals(AuthStatus.authenticated));
    });

    test('OTP timer initializes with 30s countdown and manages resend state', () async {
      await repository.setOnboardingCompleted(true);
      final viewModel = AuthViewModel(repository);
      await Future.delayed(Duration.zero);

      await viewModel.submitPhoneNumber('8123456789', isLogin: false);
      expect(viewModel.state.canResendOtp, isFalse);
      expect(viewModel.state.otpCountdownSeconds, equals(30));

      // Advance timer by 1 second to verify tick decrement
      await Future.delayed(const Duration(seconds: 1));
      expect(viewModel.state.otpCountdownSeconds, lessThan(30));
    });
  });
}
