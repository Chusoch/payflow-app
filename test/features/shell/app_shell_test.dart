import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payflow/core/router/app_router.dart';
import 'package:payflow/core/theme/app_theme.dart';
import 'package:payflow/features/auth/models/auth_state.dart';
import 'package:payflow/features/auth/view_models/auth_view_model.dart';
import 'package:payflow/features/profile/view_models/profile_view_model.dart';
import 'package:payflow/features/services/view_models/services_view_model.dart';
import 'package:payflow/features/transfer/view_models/transfer_view_model.dart';
import 'package:payflow/features/wallet/view_models/wallet_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget buildTestApp({required ProviderContainer container}) {
  return UncontrolledProviderScope(
    container: container,
    child: Consumer(
      builder: (context, ref, child) {
        final profileState = ref.watch(profileViewModelProvider);
        final router = ref.watch(appRouterProvider);
        return MaterialApp.router(
          title: 'PayFlow Test',
          theme: AppTheme.lightTheme(context),
          darkTheme: AppTheme.darkTheme(context),
          themeMode: profileState.themeMode,
          routerConfig: router,
        );
      },
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('PayFlow Authenticated App Shell & Dashboard Tests', () {
    testWidgets('1. Authenticated user reaches Home', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('payflow_onboarding_completed', true);
      await prefs.setBool('payflow_is_authenticated', true);
      await prefs.setString('payflow_auth_phone', '8123456789');
      await prefs.setString(
        'payflow_cached_profile_+2348123456789',
        jsonEncode({
          'phone': '+2348123456789',
          'displayName': 'Tunde Bakare',
          'fullName': 'Tunde Bakare',
          'email': 'tunde@example.com',
        }),
      );

      final container = ProviderContainer();
      await tester.pumpWidget(buildTestApp(container: container));
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();

      expect(find.textContaining('Tunde Bakare'), findsOneWidget);
      expect(find.text('Main Wallet Balance'), findsOneWidget);
    });

    testWidgets('2, 3, 4, 5. Bottom navigation switches to Wallet, Transfer, Services, Profile', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('payflow_onboarding_completed', true);
      await prefs.setBool('payflow_is_authenticated', true);

      final container = ProviderContainer();
      await tester.pumpWidget(buildTestApp(container: container));
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();

      // Switch to Wallet
      await tester.tap(find.text('Wallet'));
      await tester.pumpAndSettle();
      expect(find.text('Transaction History'), findsOneWidget);

      // Switch to Transfer
      await tester.tap(find.text('Transfer'));
      await tester.pumpAndSettle();
      expect(find.text('Send Money'), findsOneWidget);

      // Switch to Services
      await tester.tap(find.text('Services'));
      await tester.pumpAndSettle();
      expect(find.text('Pay Utilities'), findsOneWidget);

      // Switch to Me
      await tester.tap(find.text('Me'));
      await tester.pumpAndSettle();
      expect(find.text('Me'), findsOneWidget);
    });

    testWidgets('6. Wallet renders data from WalletViewModel', (tester) async {
      final container = ProviderContainer();
      final walletState = container.read(walletViewModelProvider);

      expect(walletState.mainBalance, equals(245850.75));
      expect(walletState.transactions.isNotEmpty, isTrue);
    });

    testWidgets('7. Transfer type switching calls appropriate ViewModel behavior', (tester) async {
      final container = ProviderContainer();
      final notifier = container.read(transferViewModelProvider.notifier);

      expect(container.read(transferViewModelProvider).selectedTransferType, equals('PayFlow User'));

      notifier.setTransferType('Bank Account');
      expect(container.read(transferViewModelProvider).selectedTransferType, equals('Bank Account'));

      notifier.setTransferType('PayFlow User');
      expect(container.read(transferViewModelProvider).selectedTransferType, equals('PayFlow User'));
    });

    testWidgets('8. Services render ViewModel-provided categories', (tester) async {
      final container = ProviderContainer();
      final servicesState = container.read(servicesViewModelProvider);

      expect(servicesState.categories.length, equals(4));
      expect(servicesState.categories.first.title, equals('Airtime'));
      expect(servicesState.categories.last.title, equals('Cable TV'));
    });

    testWidgets('9. Profile renders user data', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('payflow_auth_phone', '8123456789');
      await prefs.setString(
        'payflow_cached_profile_+2348123456789',
        jsonEncode({
          'phone': '+2348123456789',
          'displayName': 'Tunde Bakare',
          'fullName': 'Tunde Bakare',
          'email': 'tunde@example.com',
        }),
      );

      final container = ProviderContainer();
      await container.read(authRepositoryProvider).init();
      container.read(authViewModelProvider.notifier).state = const AuthState(
        status: AuthStatus.authenticated,
        phoneNumber: '8123456789',
      );
      await container.read(profileViewModelProvider.notifier).loadProfile();
      final profileState = container.read(profileViewModelProvider);

      expect(profileState.fullName, equals('Tunde Bakare'));
      expect(profileState.phoneNumber, equals('+2348123456789'));
    });

    testWidgets('10. Theme mode can switch between Light, Dark, and System', (tester) async {
      final container = ProviderContainer();
      final profileNotifier = container.read(profileViewModelProvider.notifier);

      expect(container.read(profileViewModelProvider).themeMode, equals(ThemeMode.system));

      profileNotifier.setThemeMode(ThemeMode.dark);
      expect(container.read(profileViewModelProvider).themeMode, equals(ThemeMode.dark));

      profileNotifier.setThemeMode(ThemeMode.light);
      expect(container.read(profileViewModelProvider).themeMode, equals(ThemeMode.light));

      profileNotifier.setThemeMode(ThemeMode.system);
      expect(container.read(profileViewModelProvider).themeMode, equals(ThemeMode.system));
    });

    testWidgets('11. Logout resets authentication and returns to /login', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('payflow_onboarding_completed', true);
      await prefs.setBool('payflow_is_authenticated', true);
      await prefs.setString('payflow_auth_phone', '8123456789');

      final container = ProviderContainer();
      await tester.pumpWidget(buildTestApp(container: container));
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();

      // Go to Me
      await tester.tap(find.text('Me'));
      await tester.pumpAndSettle();

      // Scroll to Log Out button and tap
      final logoutFinder = find.text('Log Out');
      await tester.ensureVisible(logoutFinder);
      await tester.tap(logoutFinder);
      await tester.pumpAndSettle();

      expect(container.read(authViewModelProvider).status, equals(AuthStatus.unauthenticated));
      expect(find.text('Welcome Back!'), findsOneWidget);
    });

    testWidgets('12. Protected routes remain inaccessible when unauthenticated', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('payflow_onboarding_completed', true);
      await prefs.setBool('payflow_is_authenticated', false);

      final container = ProviderContainer();
      await tester.pumpWidget(buildTestApp(container: container));
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();

      // Unauthenticated user cannot access protected home screen
      expect(container.read(authViewModelProvider).status, equals(AuthStatus.unauthenticated));
      expect(find.text('Main Wallet Balance'), findsNothing);
    });
  });
}
