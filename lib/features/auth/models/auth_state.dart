import 'user_model.dart';

export 'user_model.dart';

enum AuthStatus {
  initial,
  onboardingRequired,
  unauthenticated,
  awaitingOtp,
  awaitingPinSetup,
  awaitingPinConfirm,
  awaitingProfileSetup,
  awaitingPinLogin,
  awaitingBiometrics,
  authenticated,
}

class AuthState {
  final AuthStatus status;
  final String? phoneNumber;
  final String? draftPin;
  final String? fullName;
  final String? email;
  final UserModel? user;
  final bool isBiometricsEnabled;
  final bool isOnboardingCompleted;
  final bool isLoading;
  final String? errorMessage;
  final int otpCountdownSeconds;
  final bool canResendOtp;
  final bool isLoginFlow;
  final String? otpMode;
  final bool isKycVerified;
  final String? kycDateOfBirth;
  final String? kycGender;

  const AuthState({
    this.status = AuthStatus.initial,
    this.phoneNumber,
    this.draftPin,
    this.fullName,
    this.email,
    this.user,
    this.isBiometricsEnabled = false,
    this.isOnboardingCompleted = false,
    this.isLoading = false,
    this.errorMessage,
    this.otpCountdownSeconds = 30,
    this.canResendOtp = false,
    this.isLoginFlow = false,
    this.otpMode,
    this.isKycVerified = false,
    this.kycDateOfBirth,
    this.kycGender,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? phoneNumber,
    String? draftPin,
    String? fullName,
    String? email,
    UserModel? user,
    bool? isBiometricsEnabled,
    bool? isOnboardingCompleted,
    bool? isLoading,
    String? errorMessage,
    int? otpCountdownSeconds,
    bool? canResendOtp,
    bool? isLoginFlow,
    String? otpMode,
    bool? isKycVerified,
    String? kycDateOfBirth,
    String? kycGender,
  }) {
    return AuthState(
      status: status ?? this.status,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      draftPin: draftPin ?? this.draftPin,
      fullName: fullName ?? user?.fullName ?? this.fullName,
      email: email ?? user?.email ?? this.email,
      user: user ?? this.user,
      isBiometricsEnabled: isBiometricsEnabled ?? this.isBiometricsEnabled,
      isOnboardingCompleted:
          isOnboardingCompleted ?? this.isOnboardingCompleted,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      otpCountdownSeconds: otpCountdownSeconds ?? this.otpCountdownSeconds,
      canResendOtp: canResendOtp ?? this.canResendOtp,
      isLoginFlow: isLoginFlow ?? this.isLoginFlow,
      otpMode: otpMode ?? this.otpMode,
      isKycVerified: isKycVerified ?? this.isKycVerified,
      kycDateOfBirth: kycDateOfBirth ?? this.kycDateOfBirth,
      kycGender: kycGender ?? this.kycGender,
    );
  }
}
