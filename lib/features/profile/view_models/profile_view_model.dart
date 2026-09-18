import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/models/auth_state.dart';
import '../../auth/view_models/auth_view_model.dart';
import '../repositories/profile_repository.dart';

export '../models/user_profile.dart';
export '../repositories/profile_repository.dart';

class ProfileState {
  final String fullName;
  final String displayName;
  final String email;
  final String phoneNumber;
  final String accountNumber;
  final String kycLevel;
  final bool isBiometricsEnabled;
  final bool isNotificationsEnabled;
  final ThemeMode themeMode;
  final bool isLoading;
  final String? errorMessage;

  const ProfileState({
    required this.fullName,
    required this.displayName,
    required this.email,
    required this.phoneNumber,
    required this.accountNumber,
    required this.kycLevel,
    required this.isBiometricsEnabled,
    required this.isNotificationsEnabled,
    required this.themeMode,
    this.isLoading = false,
    this.errorMessage,
  });

  // Backwards-compatible getter
  String get payflowTag => phoneNumber;

  ProfileState copyWith({
    String? fullName,
    String? displayName,
    String? email,
    String? phoneNumber,
    String? accountNumber,
    String? kycLevel,
    bool? isBiometricsEnabled,
    bool? isNotificationsEnabled,
    ThemeMode? themeMode,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ProfileState(
      fullName: fullName ?? this.fullName,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      accountNumber: accountNumber ?? this.accountNumber,
      kycLevel: kycLevel ?? this.kycLevel,
      isBiometricsEnabled: isBiometricsEnabled ?? this.isBiometricsEnabled,
      isNotificationsEnabled:
          isNotificationsEnabled ?? this.isNotificationsEnabled,
      themeMode: themeMode ?? this.themeMode,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class ProfileViewModel extends StateNotifier<ProfileState> {
  final ProfileRepository _repository;
  final Ref _ref;

  ProfileViewModel({
    ProfileRepository? repository,
    required Ref ref,
  })  : _repository = repository ?? NetworkProfileRepository(),
        _ref = ref,
        super(
          const ProfileState(
            fullName: '',
            displayName: '',
            email: '',
            phoneNumber: '',
            accountNumber: '',
            kycLevel: 'Tier 1 (Basic)',
            isBiometricsEnabled: false,
            isNotificationsEnabled: true,
            themeMode: ThemeMode.system,
            isLoading: true,
          ),
        ) {
    _init();
  }

  void _init() {
    loadProfile();

    // Listen for auth state transitions (login, signup, logout)
    _ref.listen<AuthState>(authViewModelProvider, (previous, next) {
      if (next.phoneNumber != previous?.phoneNumber ||
          next.status != previous?.status ||
          next.fullName != previous?.fullName) {
        loadProfile();
      }
    });
  }

  String _deriveAccountNumber(String phone) {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length >= 10) {
      return clean.substring(clean.length - 10);
    }
    return clean;
  }

  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final authState = _ref.read(authViewModelProvider);
    final phone = authState.phoneNumber ??
        _ref.read(authRepositoryProvider).getAuthenticatedPhone();

    if (phone == null || phone.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        displayName: 'User',
        fullName: '',
        email: '',
        phoneNumber: '',
        accountNumber: '',
      );
      return;
    }

    final formattedPhone = phone.startsWith('+') ? phone : '+234${phone.replaceFirst(RegExp(r'^0'), '')}';
    final accountNum = _deriveAccountNumber(phone);

    try {
      final profile = await _repository.fetchProfile(formattedPhone);

      // Honest fallback: if fullName is absent, displayName is User +234..., NEVER a fake name
      final displayName = (profile.fullName != null && profile.fullName!.trim().isNotEmpty)
          ? profile.fullName!.trim()
          : (authState.fullName?.trim().isNotEmpty == true
              ? authState.fullName!.trim()
              : (profile.displayName.isNotEmpty
                  ? profile.displayName
                  : 'User $formattedPhone'));

      state = state.copyWith(
        isLoading: false,
        fullName: profile.fullName ?? '',
        displayName: displayName,
        email: profile.email ?? '',
        phoneNumber: formattedPhone,
        accountNumber: accountNum,
        isBiometricsEnabled: authState.isBiometricsEnabled,
      );
    } catch (e) {
      final savedName = _ref.read(authRepositoryProvider).getSavedFullName();
      state = state.copyWith(
        isLoading: false,
        displayName: savedName?.isNotEmpty == true ? savedName! : 'User $formattedPhone',
        fullName: savedName ?? '',
        phoneNumber: formattedPhone,
        accountNumber: accountNum,
        errorMessage: 'Failed to load profile details',
      );
    }
  }

  Future<bool> updateProfile({required String fullName, String? email}) async {
    final cleanName = fullName.trim();
    if (cleanName.isEmpty) {
      state = state.copyWith(errorMessage: 'Full name cannot be empty');
      return false;
    }

    final authState = _ref.read(authViewModelProvider);
    final phone = authState.phoneNumber ??
        _ref.read(authRepositoryProvider).getAuthenticatedPhone();

    if (phone == null || phone.isEmpty) {
      state = state.copyWith(errorMessage: 'No authenticated user session');
      return false;
    }

    final formattedPhone = phone.startsWith('+') ? phone : '+234${phone.replaceFirst(RegExp(r'^0'), '')}';

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final updated = await _repository.updateProfile(
        formattedPhone,
        fullName: cleanName,
        email: email,
      );

      final displayName = (updated.fullName != null && updated.fullName!.isNotEmpty)
          ? updated.fullName!
          : cleanName;

      state = state.copyWith(
        isLoading: false,
        fullName: cleanName,
        displayName: displayName,
        email: updated.email ?? (email?.trim() ?? state.email),
        errorMessage: null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to update profile. Please try again.',
      );
      return false;
    }
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
  }

  void toggleTheme(bool isDark) {
    state = state.copyWith(
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
    );
  }

  void toggleBiometrics(bool value) {
    state = state.copyWith(isBiometricsEnabled: value);
  }

  void toggleNotifications(bool value) {
    state = state.copyWith(isNotificationsEnabled: value);
  }
}

final profileViewModelProvider =
    StateNotifierProvider<ProfileViewModel, ProfileState>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  return ProfileViewModel(repository: repository, ref: ref);
});
