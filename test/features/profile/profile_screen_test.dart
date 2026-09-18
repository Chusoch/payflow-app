import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payflow/features/auth/models/auth_state.dart';
import 'package:payflow/features/auth/repositories/auth_repository.dart';
import 'package:payflow/features/auth/view_models/auth_view_model.dart';
import 'package:payflow/features/profile/view_models/profile_view_model.dart';
import 'package:payflow/features/profile/views/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockProfileRepo implements ProfileRepository {
  UserProfile currentProfile;
  MockProfileRepo({required this.currentProfile});

  @override
  Future<UserProfile> fetchProfile(String phone) async {
    return currentProfile;
  }

  @override
  Future<UserProfile> updateProfile(
    String phone, {
    required String fullName,
    String? email,
  }) async {
    currentProfile = currentProfile.copyWith(
      fullName: fullName,
      displayName: fullName,
      email: email,
    );
    return currentProfile;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createWidgetUnderTest({
    required ProfileRepository repo,
    AuthRepository? authRepo,
    ProfileState? initialState,
    String phone = '+2348123456789',
  }) {
    final effectiveAuthRepo = authRepo ?? MockAuthRepository();
    return ProviderScope(
      overrides: [
        profileRepositoryProvider.overrideWithValue(repo),
        authRepositoryProvider.overrideWithValue(effectiveAuthRepo),
        authViewModelProvider.overrideWith(
          (ref) => AuthViewModel(effectiveAuthRepo)
            ..state = AuthState(
              status: AuthStatus.authenticated,
              phoneNumber: phone,
            ),
        ),
        if (initialState != null)
          profileViewModelProvider.overrideWith(
            (ref) => ProfileViewModel(repository: repo, ref: ref)
              ..state = initialState,
          ),
      ],
      child: const MaterialApp(
        home: ProfileScreen(),
      ),
    );
  }

  group('ProfileScreen & Dead-End Action Tests', () {
    testWidgets('1. Displays honest fallback "User +234..." when no fullName is set', (tester) async {
      final repo = MockProfileRepo(
        currentProfile: const UserProfile(
          phone: '+2348123456789',
          displayName: 'User +2348123456789',
          fullName: null,
          email: null,
        ),
      );

      final state = const ProfileState(
        fullName: '',
        displayName: 'User +2348123456789',
        email: '',
        phoneNumber: '+2348123456789',
        accountNumber: '8123456789',
        kycLevel: 'Tier 1 (Basic)',
        isBiometricsEnabled: false,
        isNotificationsEnabled: true,
        themeMode: ThemeMode.system,
      );

      await tester.pumpWidget(createWidgetUnderTest(repo: repo, initialState: state));
      await tester.pumpAndSettle();

      expect(find.text('User +2348123456789'), findsOneWidget);
      expect(find.text('Alex Johnson'), findsNothing);
      expect(find.text('U'), findsOneWidget);
    });

    testWidgets('2. Displays real user name and email when populated', (tester) async {
      final repo = MockProfileRepo(
        currentProfile: const UserProfile(
          phone: '+2348123456789',
          displayName: 'Tunde Bakare',
          fullName: 'Tunde Bakare',
          email: 'tunde@example.com',
        ),
      );

      final state = const ProfileState(
        fullName: 'Tunde Bakare',
        displayName: 'Tunde Bakare',
        email: 'tunde@example.com',
        phoneNumber: '+2348123456789',
        accountNumber: '8123456789',
        kycLevel: 'Tier 1 (Basic)',
        isBiometricsEnabled: false,
        isNotificationsEnabled: true,
        themeMode: ThemeMode.system,
      );

      await tester.pumpWidget(createWidgetUnderTest(repo: repo, initialState: state));
      await tester.pumpAndSettle();

      expect(find.text('Tunde Bakare'), findsWidgets);
      expect(find.text('+2348123456789'), findsWidgets);
      expect(find.text('T'), findsOneWidget);
    });

    testWidgets('3. Change Transaction PIN: verifies current PIN and persists genuine new PIN', (tester) async {
      final authRepo = MockAuthRepository();
      await authRepo.init();
      // Default initial pin in MockAuthRepository is '1234'
      expect(await authRepo.verifyPin('+2348123456789', '1234'), isTrue);

      final repo = MockProfileRepo(
        currentProfile: const UserProfile(phone: '+2348123456789', displayName: 'Tunde Bakare'),
      );

      await tester.pumpWidget(createWidgetUnderTest(repo: repo, authRepo: authRepo));
      await tester.pumpAndSettle();

      final pinTile = find.text('Change Transaction PIN');
      await tester.ensureVisible(pinTile);
      await tester.tap(pinTile);
      await tester.pumpAndSettle();

      expect(find.text('Change Transaction PIN'), findsWidgets);
      expect(find.text('Update PIN'), findsOneWidget);

      final fields = find.byType(TextFormField);
      final currentPinField = fields.at(0);
      final newPinField = fields.at(1);
      final confirmPinField = fields.at(2);

      // Attempt 1: Incorrect current PIN
      await tester.enterText(currentPinField, '0000');
      await tester.enterText(newPinField, '5678');
      await tester.enterText(confirmPinField, '5678');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Update PIN'));
      await tester.pumpAndSettle();

      expect(find.text('Current PIN is incorrect.'), findsOneWidget);
      // Storage must remain untouched
      expect(await authRepo.verifyPin('+2348123456789', '1234'), isTrue);
      expect(await authRepo.verifyPin('+2348123456789', '5678'), isFalse);

      // Attempt 2: Correct current PIN '1234' and valid new PIN '5678'
      await tester.enterText(currentPinField, '1234');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Update PIN'));
      await tester.pumpAndSettle();

      expect(find.text('Transaction PIN updated successfully!'), findsOneWidget);

      // Genuine state persistence verified: old PIN now fails, new PIN now succeeds!
      expect(await authRepo.verifyPin('+2348123456789', '1234'), isFalse);
      expect(await authRepo.verifyPin('+2348123456789', '5678'), isTrue);
    });

    testWidgets('4. Help & Support Center dead-end resolved: opens bottom sheet with support channels', (tester) async {
      final repo = MockProfileRepo(
        currentProfile: const UserProfile(phone: '+2348123456789', displayName: 'Tunde Bakare'),
      );

      await tester.pumpWidget(createWidgetUnderTest(repo: repo));
      await tester.pumpAndSettle();

      final helpTile = find.text('Help & Support Center');
      await tester.ensureVisible(helpTile);
      await tester.tap(helpTile);
      await tester.pumpAndSettle();

      expect(find.text('Email Support'), findsOneWidget);
      expect(find.text('support@payflow.app'), findsOneWidget);
      expect(find.text('Toll-Free Phone Support'), findsOneWidget);
      expect(find.text('0800 PAYFLOW (0800 729 3569)'), findsOneWidget);
      expect(find.text('24/7 In-App Live Chat'), findsOneWidget);

      await tester.tap(find.text('24/7 In-App Live Chat'));
      await tester.pumpAndSettle();

      expect(find.text('Live Chat queue connected. An agent will respond shortly.'), findsOneWidget);
    });

    testWidgets('4b. Help & Support Center modal does not overflow on height-constrained screens', (tester) async {
      tester.view.physicalSize = const Size(800, 350);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = MockProfileRepo(
        currentProfile: const UserProfile(phone: '+2348123456789', displayName: 'Tunde Bakare'),
      );

      await tester.pumpWidget(createWidgetUnderTest(repo: repo));
      await tester.pumpAndSettle();

      final helpTile = find.text('Help & Support Center');
      await tester.ensureVisible(helpTile);
      await tester.tap(helpTile);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Email Support'), findsOneWidget);
      expect(find.text('support@payflow.app'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsWidgets);
    });

    testWidgets('5. Privacy Policy & Terms dead-end resolved: opens policy document modal', (tester) async {
      final repo = MockProfileRepo(
        currentProfile: const UserProfile(phone: '+2348123456789', displayName: 'Tunde Bakare'),
      );

      await tester.pumpWidget(createWidgetUnderTest(repo: repo));
      await tester.pumpAndSettle();

      final policyTile = find.text('Privacy Policy & Terms');
      await tester.ensureVisible(policyTile);
      await tester.tap(policyTile);
      await tester.pumpAndSettle();

      expect(find.text('NDPR & CBN Compliance'), findsOneWidget);
      expect(find.textContaining('Nigeria Data Protection Regulation (NDPR)'), findsOneWidget);
    });

    testWidgets('6. Edit Profile action opens modal and updates profile state', (tester) async {
      final repo = MockProfileRepo(
        currentProfile: const UserProfile(
          phone: '+2348123456789',
          displayName: 'Initial Name',
          fullName: 'Initial Name',
          email: 'initial@payflow.app',
        ),
      );

      final state = const ProfileState(
        fullName: 'Initial Name',
        displayName: 'Initial Name',
        email: 'initial@payflow.app',
        phoneNumber: '+2348123456789',
        accountNumber: '8123456789',
        kycLevel: 'Tier 1 (Basic)',
        isBiometricsEnabled: false,
        isNotificationsEnabled: true,
        themeMode: ThemeMode.system,
      );

      await tester.pumpWidget(createWidgetUnderTest(repo: repo, initialState: state));
      await tester.pumpAndSettle();

      final editBtn = find.byTooltip('Edit Profile');
      expect(editBtn, findsOneWidget);
      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      expect(find.text('Edit Profile'), findsWidgets);
      expect(find.text('Save Changes'), findsOneWidget);

      final nameField = find.byWidgetPredicate(
        (w) => w is TextFormField && w.controller?.text == 'Initial Name',
      );
      await tester.enterText(nameField, 'Updated Full Name');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Profile updated successfully'), findsOneWidget);
      expect(find.text('Updated Full Name'), findsWidgets);
    });

    testWidgets('7. Displays Tier 1 (Basic) badge for authenticated phone-verified user', (tester) async {
      final repo = MockProfileRepo(
        currentProfile: const UserProfile(
          phone: '+2348123456789',
          displayName: 'User +2348123456789',
        ),
      );

      final state = const ProfileState(
        fullName: '',
        displayName: 'User +2348123456789',
        email: '',
        phoneNumber: '+2348123456789',
        accountNumber: '8123456789',
        kycLevel: 'Tier 1 (Basic)',
        isBiometricsEnabled: false,
        isNotificationsEnabled: true,
        themeMode: ThemeMode.system,
      );

      await tester.pumpWidget(createWidgetUnderTest(repo: repo, initialState: state));
      await tester.pumpAndSettle();

      expect(find.text('Tier 1 (Active)'), findsOneWidget);
      expect(find.text('Tier 1 (Basic)'), findsOneWidget);
      expect(find.text('Tier 1 (Unverified)'), findsNothing);
    });
  });
}
