import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/notifications/notification_service.dart';
import '../models/auth_state.dart';
import '../repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return MockAuthRepository();
});

class AuthViewModel extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final FirebaseAuth? _firebaseAuth;
  final Future<void> Function()? _waitForNativeAuth;
  Timer? _timer;

  FirebaseAuth get _auth => _firebaseAuth ?? FirebaseAuth.instance;

  AuthViewModel(
    this._repository, {
    FirebaseAuth? auth,
    Future<void> Function()? waitForNativeAuth,
  })  : _firebaseAuth = auth,
        _waitForNativeAuth = waitForNativeAuth,
        super(const AuthState()) {
    restoreSession();
  }

  Future<bool> _waitForNativeSession() async {
    if (_waitForNativeAuth != null) {
      try {
        await _waitForNativeAuth();
        return true;
      } catch (e) {
        debugPrint('[PayFlow Auth] Native session restoration failed: $e');
        return false;
      }
    }

    final customToken = _repository.getCustomToken();
    if (Env.isMockMode && _firebaseAuth == null) return true;
    if (customToken != null && customToken.split('.').length == 3 && !customToken.startsWith('mock_')) return true;

    try {
      bool hasUser = false;
      try {
        hasUser = _auth.currentUser != null || FirebaseAuth.instance.currentUser != null;
      } catch (_) {}
      if (hasUser) {
        return true;
      }

      // Explicitly await native auth restoration until initial state is confirmed
      final user = await _auth
          .authStateChanges()
          .first
          .timeout(const Duration(seconds: 5));
      return user != null;
    } catch (e) {
      debugPrint('[PayFlow Auth] Native session restoration notice: $e');
      return false;
    }
  }

  Future<void> checkInitialState() => restoreSession();

  Future<void> restoreSession() async {
    state = state.copyWith(isLoading: true);
    final completer = Completer<void>();
    ApiClient.authResolutionInProgress = completer.future;

    try {
      await _repository.init();

      final isOnboardingCompleted = _repository.isOnboardingCompleted();
      final hasActiveSession = _repository.hasActiveSession();
      final isBiometricsEnabled = _repository.isBiometricsEnabled();
      final savedPhone = _repository.getAuthenticatedPhone();
      final savedName = _repository.getSavedFullName();
      final savedEmail = _repository.getSavedEmail();

      if (!isOnboardingCompleted) {
        state = state.copyWith(
          status: AuthStatus.onboardingRequired,
          isOnboardingCompleted: false,
          isLoading: false,
        );
      } else if (hasActiveSession) {
        final rawToken = _repository.getRawCustomToken();
        if (rawToken != null && (rawToken.startsWith('mock_') || rawToken.split('.').length != 3)) {
          debugPrint('[AuthViewModel] Stored token is invalid or missing 3 dot-separated segments. Clearing and navigating to login.');
          await _repository.clearSession();
          defaultApiClient.setToken(null);
          state = state.copyWith(
            status: AuthStatus.unauthenticated,
            isOnboardingCompleted: true,
            isBiometricsEnabled: isBiometricsEnabled,
            phoneNumber: savedPhone,
            fullName: savedName,
            email: savedEmail,
            isLoading: false,
          );
          return;
        }

        final savedToken = _repository.getCustomToken();
        if (savedToken != null && savedToken.isNotEmpty) {
          defaultApiClient.setToken(savedToken);
          try {
            await FirebaseAuth.instance.signInWithCustomToken(savedToken);
          } catch (e) {
            debugPrint('[AuthService] Firebase custom token sign-in warning: $e');
          }
        }

        // Await native Firebase Auth restoration or accept active session from local storage
        final isSessionValid = await _waitForNativeSession();

        if (isSessionValid) {
          debugPrint('[ProfileHydration] Fetching profile for: $savedPhone');
          UserModel? profile;
          try {
            profile = await _repository.getUserProfile(savedPhone);
          } catch (e) {
            debugPrint('[AuthViewModel] Error fetching user profile on session restoration: $e');
          }
          debugPrint('[ProfileHydration] Result: ${profile?.fullName}');

          final effectiveFullName = (profile?.fullName != null && profile!.fullName!.trim().isNotEmpty)
              ? profile.fullName!.trim()
              : (savedName != null && savedName.trim().isNotEmpty ? savedName.trim() : state.fullName);
          final effectiveEmail = (profile?.email != null && profile!.email!.trim().isNotEmpty)
              ? profile.email!.trim()
              : (savedEmail != null && savedEmail.trim().isNotEmpty ? savedEmail.trim() : state.email);

          // Fallback to Stored User Name:
          // If profile is null or has empty fullName, populate from cached values so it never displays generic "User"
          if ((profile == null || profile.fullName == null || profile.fullName!.isEmpty) &&
              effectiveFullName != null &&
              effectiveFullName.isNotEmpty) {
            profile = UserModel(
              phoneNumber: savedPhone,
              fullName: effectiveFullName,
              email: effectiveEmail,
              displayName: effectiveFullName,
            );
          }

          state = state.copyWith(
            status: AuthStatus.authenticated,
            isOnboardingCompleted: true,
            isBiometricsEnabled: isBiometricsEnabled,
            phoneNumber: savedPhone,
            fullName: effectiveFullName,
            email: effectiveEmail,
            user: profile,
            isLoading: false,
          );

          if (savedPhone != null && savedPhone.isNotEmpty) {
            NotificationService().startRealtimeNotifications(savedPhone);
          }

          debugPrint('[WalletHydration] Fetching wallet balance...');
        } else {
          // If local storage says a session exists, but Firebase Auth resolves to null
          // within a sensible timeout, clear the local flag and emit AuthState.unauthenticated().
          await _repository.clearSession();
          defaultApiClient.setToken(null);
          state = state.copyWith(
            status: AuthStatus.unauthenticated,
            isOnboardingCompleted: true,
            isBiometricsEnabled: isBiometricsEnabled,
            phoneNumber: savedPhone,
            fullName: savedName,
            email: savedEmail,
            isLoading: false,
          );
        }
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          isOnboardingCompleted: true,
          isBiometricsEnabled: isBiometricsEnabled,
          phoneNumber: savedPhone,
          fullName: savedName,
          email: savedEmail,
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        isLoading: false,
      );
    } finally {
      if (!completer.isCompleted) {
        completer.complete();
      }
      ApiClient.authResolutionInProgress = null;
    }
  }

  Future<void> completeOnboarding() async {
    await _repository.setOnboardingCompleted(true);
    state = state.copyWith(
      isOnboardingCompleted: true,
      status: AuthStatus.unauthenticated,
    );
  }

  String? _pinId;

  Future<bool> submitPhoneNumber(String phone, {bool isLogin = false}) async {
    final cleanPhone = phone.trim();
    if (cleanPhone.isEmpty || cleanPhone.length < 10) {
      state = state.copyWith(
        errorMessage: 'Please enter a valid 10 or 11 digit phone number.',
      );
      return false;
    }

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      phoneNumber: cleanPhone,
      isLoginFlow: isLogin,
    );

    try {
      final result = await _repository.sendOtp(cleanPhone);

      if (result.isSuccess && result.pinId != null && result.pinId!.isNotEmpty) {
        _pinId = result.pinId;
        state = state.copyWith(
          isLoading: false,
          status: AuthStatus.awaitingOtp,
          otpCountdownSeconds: 30,
          canResendOtp: false,
          otpMode: result.mode,
        );
        _startOtpTimer();
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: result.errorMessage ?? 'Failed to send OTP. Please try again.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'An unexpected error occurred. Please try again.',
      );
      return false;
    }
  }

  void _startOtpTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.otpCountdownSeconds > 1) {
        state = state.copyWith(
          otpCountdownSeconds: state.otpCountdownSeconds - 1,
        );
      } else {
        _timer?.cancel();
        state = state.copyWith(
          otpCountdownSeconds: 0,
          canResendOtp: true,
        );
      }
    });
  }

  Future<bool> verifyOtp(String otp) async {
    if (otp.length != 6) {
      state = state.copyWith(errorMessage: 'Please enter a 6-digit OTP code.');
      return false;
    }

    final pinId = _pinId;
    if (pinId == null || pinId.isEmpty) {
      state = state.copyWith(
        errorMessage: 'OTP session invalid. Please request a new code.',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final customToken = await _repository.verifyOtp(pinId, otp);

      if (customToken != null && customToken.isNotEmpty) {
        if (customToken.startsWith('mock_') || customToken.split('.').length != 3) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: 'Security error: received invalid authentication token format.',
          );
          return false;
        }

        await _repository.saveCustomToken(customToken);
        defaultApiClient.setToken(customToken);

        try {
          await FirebaseAuth.instance.signInWithCustomToken(customToken);
        } catch (e) {
          debugPrint('[AuthService] Firebase custom token sign-in warning: $e');
        }

        if (_firebaseAuth != null && _firebaseAuth != FirebaseAuth.instance) {
          try {
            await _firebaseAuth.signInWithCustomToken(customToken);
          } catch (_) {}
        }

        _timer?.cancel();
        if (state.isLoginFlow) {
          state = state.copyWith(
            isLoading: false,
            status: AuthStatus.awaitingPinLogin,
          );
        } else {
          state = state.copyWith(
            isLoading: false,
            status: AuthStatus.awaitingPinSetup,
          );
        }
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: _repository.lastVerifyErrorMessage ??
              'Invalid OTP. Use 123456 for dev testing.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'OTP verification failed. Please try again.',
      );
      return false;
    }
  }

  Future<void> resendOtp() async {
    if (!state.canResendOtp) return;

    final phone = state.phoneNumber;
    if (phone == null || phone.isEmpty) {
      state = state.copyWith(errorMessage: 'Phone number is missing.');
      return;
    }

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      canResendOtp: false,
    );

    try {
      final result = await _repository.sendOtp(phone);
      if (result.isSuccess) {
        if (result.pinId != null && result.pinId!.isNotEmpty) {
          _pinId = result.pinId;
        }
        state = state.copyWith(
          isLoading: false,
          otpCountdownSeconds: 30,
          otpMode: result.mode,
        );
        _startOtpTimer();
      } else {
        state = state.copyWith(
          isLoading: false,
          canResendOtp: true,
          errorMessage: result.errorMessage ?? 'Failed to resend OTP.',
        );
      }
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        canResendOtp: true,
        errorMessage: 'Failed to resend OTP.',
      );
    }
  }

  void setDraftPin(String pin) {
    if (pin.length != 4) {
      state = state.copyWith(errorMessage: 'PIN must be 4 digits.');
      return;
    }
    state = state.copyWith(
      draftPin: pin,
      status: AuthStatus.awaitingPinConfirm,
      errorMessage: null,
    );
  }

  Future<bool> confirmPin(String pin) async {
    if (pin != state.draftPin) {
      state = state.copyWith(
        errorMessage: 'PINs do not match. Please try again.',
      );
      return false;
    }

    final phone = state.phoneNumber;
    if (phone == null || phone.isEmpty) {
      state = state.copyWith(errorMessage: 'Phone number is missing.');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final success = await _repository.setupPin(pin);
      if (success) {
        await _repository.verifyPin(phone, pin);

        state = state.copyWith(
          isLoading: false,
          draftPin: null,
          status: AuthStatus.awaitingProfileSetup,
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to set PIN. Please try again.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to save PIN. Please try again.',
      );
      return false;
    }
  }

  Future<bool> changePin({
    required String currentPin,
    required String newPin,
    required String confirmPin,
  }) async {
    if (currentPin.length != 4) {
      state = state.copyWith(errorMessage: 'Current PIN must be 4 digits.');
      return false;
    }
    if (newPin.length != 4) {
      state = state.copyWith(errorMessage: 'New PIN must be 4 digits.');
      return false;
    }
    if (newPin != confirmPin) {
      state = state.copyWith(errorMessage: 'New PINs do not match.');
      return false;
    }
    if (currentPin == newPin) {
      state = state.copyWith(errorMessage: 'New PIN must be different from current PIN.');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final phone = state.phoneNumber ?? _repository.getAuthenticatedPhone() ?? '';
      final isValid = await _repository.verifyPin(phone, currentPin);
      if (!isValid) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Current PIN is incorrect.',
        );
        return false;
      }

      final success = await _repository.setupPin(newPin);
      if (success) {
        state = state.copyWith(isLoading: false, errorMessage: null);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to update PIN. Please try again.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'An error occurred while changing PIN.',
      );
      return false;
    }
  }

  void setVerifiedKycIdentity({
    required String fullName,
    String? dateOfBirth,
    String? gender,
    String? phone,
  }) {
    state = state.copyWith(
      fullName: fullName,
      isKycVerified: true,
      kycDateOfBirth: dateOfBirth,
      kycGender: gender,
      phoneNumber: phone ?? state.phoneNumber,
    );
  }

  Future<bool> submitProfile({required String fullName, String? email}) async {
    final cleanName = fullName.trim();
    if (cleanName.isEmpty) {
      state = state.copyWith(errorMessage: 'Please enter your full name.');
      return false;
    }

    final phone = state.phoneNumber ?? _repository.getAuthenticatedPhone();
    if (phone == null || phone.isEmpty) {
      state = state.copyWith(errorMessage: 'Phone number is missing.');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final cleanEmail = email?.trim();
      await _repository.saveUserProfile(
        phone,
        fullName: cleanName,
        email: cleanEmail != null && cleanEmail.isNotEmpty ? cleanEmail : null,
      );

      final canBiometrics = await _repository.canCheckBiometrics();
        final userModel = UserModel(
          phoneNumber: phone,
          fullName: cleanName,
          email: cleanEmail != null && cleanEmail.isNotEmpty ? cleanEmail : null,
          displayName: cleanName,
        );

        if (canBiometrics) {
          state = state.copyWith(
            isLoading: false,
            fullName: cleanName,
            email: cleanEmail != null && cleanEmail.isNotEmpty ? cleanEmail : null,
            user: userModel,
            status: AuthStatus.awaitingBiometrics,
          );
        } else {
          state = state.copyWith(
            isLoading: false,
            fullName: cleanName,
            email: cleanEmail != null && cleanEmail.isNotEmpty ? cleanEmail : null,
            user: userModel,
            status: AuthStatus.authenticated,
          );
        }
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to save profile. Please try again.',
      );
      return false;
    }
  }

  Future<void> setupBiometrics(bool enable) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.setBiometricsEnabled(enable);
      if (enable) {
        await _repository.authenticateWithBiometrics();
      }
    } catch (_) {}

    state = state.copyWith(
      isLoading: false,
      isBiometricsEnabled: enable,
      status: AuthStatus.authenticated,
    );
  }

  Future<bool> loginWithPin(String pin, {String? identifier}) async {
    if (pin.length != 4) {
      state = state.copyWith(errorMessage: 'Enter a 4-digit passcode.');
      return false;
    }

    final cleanId = identifier?.trim();
    final phone = (cleanId != null && cleanId.isNotEmpty)
        ? cleanId
        : (state.phoneNumber ??
            _repository.getAuthenticatedPhone() ??
            state.email ??
            _repository.getSavedEmail());

    if (phone == null || phone.isEmpty) {
      state = state.copyWith(errorMessage: 'Phone number or email is missing for login.');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final success = await _repository.verifyPin(phone, pin);

      if (success) {
        final customToken = _repository.getCustomToken();
        if (customToken != null && customToken.isNotEmpty) {
          defaultApiClient.setToken(customToken);
          bool hasUser = false;
          try {
            hasUser = _auth.currentUser != null || FirebaseAuth.instance.currentUser != null;
          } catch (_) {}

          if (!hasUser) {
            try {
              await FirebaseAuth.instance.signInWithCustomToken(customToken);
            } catch (e) {
              debugPrint('[AuthService] Firebase custom token sign-in warning: $e');
            }
          }
        }

        UserModel? profile;
        try {
          profile = await _repository.getUserProfile(phone);
        } catch (_) {}

        final effectiveFullName = (profile?.fullName != null && profile!.fullName!.trim().isNotEmpty)
            ? profile.fullName!.trim()
            : state.fullName;
        final effectiveEmail = (profile?.email != null && profile!.email!.trim().isNotEmpty)
            ? profile.email!.trim()
            : state.email;

        state = state.copyWith(
          isLoading: false,
          phoneNumber: phone,
          fullName: effectiveFullName,
          email: effectiveEmail,
          user: profile ?? state.user,
          status: AuthStatus.authenticated,
        );
        NotificationService().startRealtimeNotifications(phone);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Incorrect PIN / passcode. Try 1234 for dev testing.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Authentication failed. Please try again.',
      );
      return false;
    }
  }

  Future<bool> loginWithBiometrics() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final success = await _repository.authenticateWithBiometrics();

      if (success) {
        final phone = state.phoneNumber ?? _repository.getAuthenticatedPhone();
        state = state.copyWith(
          isLoading: false,
          phoneNumber: phone,
          status: AuthStatus.authenticated,
        );
        if (phone != null && phone.isNotEmpty) {
          NotificationService().startRealtimeNotifications(phone);
        }
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Biometric authentication failed or cancelled.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Biometric authentication error.',
      );
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() => loginWithBiometrics();

  Future<void> switchAccount() async {
    _timer?.cancel();
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('saved_user_phone');
        await prefs.remove('saved_user_email');
        await prefs.remove('saved_user_name');
        await prefs.remove('payflow_auth_phone');
        await prefs.remove('payflow_user_fullname');
        await prefs.remove('payflow_user_email');
      } catch (_) {}
    } else {
      try {
        const secureStorage = FlutterSecureStorage();
        await secureStorage
            .delete(key: 'saved_user_phone')
            .timeout(const Duration(milliseconds: 50));
        await secureStorage
            .delete(key: 'saved_user_email')
            .timeout(const Duration(milliseconds: 50));
        await secureStorage
            .delete(key: 'saved_user_name')
            .timeout(const Duration(milliseconds: 50));
        await secureStorage
            .delete(key: 'payflow_auth_phone')
            .timeout(const Duration(milliseconds: 50));
        await secureStorage
            .delete(key: 'payflow_user_fullname')
            .timeout(const Duration(milliseconds: 50));
        await secureStorage
            .delete(key: 'payflow_user_email')
            .timeout(const Duration(milliseconds: 50));
        await secureStorage
            .deleteAll()
            .timeout(const Duration(milliseconds: 50));
      } catch (_) {}
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('saved_user_phone');
        await prefs.remove('saved_user_email');
        await prefs.remove('saved_user_name');
        await prefs.remove('payflow_auth_phone');
        await prefs.remove('payflow_user_fullname');
        await prefs.remove('payflow_user_email');
      } catch (_) {}
    }
    await _repository.clearSavedIdentity();
    defaultApiClient.setToken(null);
    state = const AuthState(
      status: AuthStatus.unauthenticated,
      isOnboardingCompleted: true,
      phoneNumber: null,
      fullName: null,
      email: null,
    );
  }

  Future<void> logout() async {
    _timer?.cancel();
    await _repository.logout();
    defaultApiClient.setToken(null);
    NotificationService().stopRealtimeNotifications();
    state = const AuthState(
      status: AuthStatus.unauthenticated,
      isOnboardingCompleted: true,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final nativeAuthRestorerProvider =
    Provider<Future<void> Function()?>((ref) => null);

final firebaseAuthProvider = Provider<FirebaseAuth?>((ref) => null);

final authViewModelProvider =
    StateNotifierProvider<AuthViewModel, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  final waitForNativeAuth = ref.watch(nativeAuthRestorerProvider);
  final auth = ref.watch(firebaseAuthProvider);
  return AuthViewModel(
    repository,
    auth: auth,
    waitForNativeAuth: waitForNativeAuth,
  );
});
