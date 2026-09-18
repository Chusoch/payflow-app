import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payflow/features/auth/models/auth_state.dart';
import 'package:payflow/features/auth/view_models/auth_view_model.dart';
import 'package:payflow/features/profile/view_models/profile_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockTestProfileRepo implements ProfileRepository {
  UserProfile profileToReturn;
  bool wasUpdateCalled = false;
  String? lastUpdatedName;
  String? lastUpdatedEmail;

  MockTestProfileRepo({required this.profileToReturn});

  @override
  Future<UserProfile> fetchProfile(String phone) async {
    return profileToReturn;
  }

  @override
  Future<UserProfile> updateProfile(
    String phone, {
    required String fullName,
    String? email,
  }) async {
    wasUpdateCalled = true;
    lastUpdatedName = fullName;
    lastUpdatedEmail = email;
    profileToReturn = profileToReturn.copyWith(
      fullName: fullName,
      displayName: fullName,
      email: email,
    );
    return profileToReturn;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ProfileViewModel Unit Tests', () {
    test('1. Unauthenticated user has honest fallback "User" with empty fields', () async {
      final repo = MockTestProfileRepo(
        profileToReturn: const UserProfile(phone: ''),
      );

      final container = ProviderContainer(
        overrides: [
          profileRepositoryProvider.overrideWithValue(repo),
        ],
      );

      final viewModel = container.read(profileViewModelProvider.notifier);
      await viewModel.loadProfile();

      final state = container.read(profileViewModelProvider);
      expect(state.displayName, equals('User'));
      expect(state.fullName, isEmpty);
      expect(state.email, isEmpty);
      expect(state.accountNumber, isEmpty);
    });

    test('2. Authenticated user without custom name gets honest fallback "User +234..."', () async {
      final repo = MockTestProfileRepo(
        profileToReturn: const UserProfile(
          phone: '+2348012345678',
          displayName: 'User +2348012345678',
          fullName: null,
          email: null,
        ),
      );

      final container = ProviderContainer(
        overrides: [
          profileRepositoryProvider.overrideWithValue(repo),
        ],
      );

      // Pre-seed auth state with phone
      container.read(authViewModelProvider.notifier).state = const AuthState(
        status: AuthStatus.authenticated,
        phoneNumber: '08012345678',
      );

      final viewModel = container.read(profileViewModelProvider.notifier);
      await viewModel.loadProfile();

      final state = container.read(profileViewModelProvider);
      expect(state.displayName, equals('User +2348012345678'));
      expect(state.fullName, isEmpty);
      expect(state.accountNumber, equals('8012345678'));
    });

    test('3. Authenticated user with real name displays real fullName and email', () async {
      final repo = MockTestProfileRepo(
        profileToReturn: const UserProfile(
          phone: '+2348012345678',
          displayName: 'Amina Yusuf',
          fullName: 'Amina Yusuf',
          email: 'amina@example.com',
        ),
      );

      final container = ProviderContainer(
        overrides: [
          profileRepositoryProvider.overrideWithValue(repo),
        ],
      );

      container.read(authViewModelProvider.notifier).state = const AuthState(
        status: AuthStatus.authenticated,
        phoneNumber: '08012345678',
      );

      final viewModel = container.read(profileViewModelProvider.notifier);
      await viewModel.loadProfile();

      final state = container.read(profileViewModelProvider);
      expect(state.displayName, equals('Amina Yusuf'));
      expect(state.fullName, equals('Amina Yusuf'));
      expect(state.email, equals('amina@example.com'));
      expect(state.accountNumber, equals('8012345678'));
    });

    test('4. updateProfile calls repository and updates state', () async {
      final repo = MockTestProfileRepo(
        profileToReturn: const UserProfile(
          phone: '+2348012345678',
          displayName: 'Old Name',
          fullName: 'Old Name',
          email: 'old@example.com',
        ),
      );

      final container = ProviderContainer(
        overrides: [
          profileRepositoryProvider.overrideWithValue(repo),
        ],
      );

      container.read(authViewModelProvider.notifier).state = const AuthState(
        status: AuthStatus.authenticated,
        phoneNumber: '08012345678',
      );

      final viewModel = container.read(profileViewModelProvider.notifier);
      await viewModel.loadProfile();

      final success = await viewModel.updateProfile(
        fullName: 'New Updated Name',
        email: 'new@example.com',
      );

      expect(success, isTrue);
      expect(repo.wasUpdateCalled, isTrue);
      expect(repo.lastUpdatedName, equals('New Updated Name'));
      expect(repo.lastUpdatedEmail, equals('new@example.com'));

      final state = container.read(profileViewModelProvider);
      expect(state.fullName, equals('New Updated Name'));
      expect(state.displayName, equals('New Updated Name'));
      expect(state.email, equals('new@example.com'));
    });

    test('5. Theme and settings toggles work correctly', () async {
      final repo = MockTestProfileRepo(
        profileToReturn: const UserProfile(phone: '+2348012345678'),
      );

      final container = ProviderContainer(
        overrides: [
          profileRepositoryProvider.overrideWithValue(repo),
        ],
      );

      final viewModel = container.read(profileViewModelProvider.notifier);

      viewModel.setThemeMode(ThemeMode.dark);
      expect(container.read(profileViewModelProvider).themeMode, equals(ThemeMode.dark));

      viewModel.toggleBiometrics(true);
      expect(container.read(profileViewModelProvider).isBiometricsEnabled, isTrue);

      viewModel.toggleNotifications(false);
      expect(container.read(profileViewModelProvider).isNotificationsEnabled, isFalse);
    });
  });
}
