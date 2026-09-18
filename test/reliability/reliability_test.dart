import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payflow/core/payment/models/payment_status.dart';
import 'package:payflow/core/payment/providers/mock_payment_provider.dart';
import 'package:payflow/core/payment/services/payment_service.dart';
import 'package:payflow/core/router/app_router.dart';
import 'package:payflow/core/theme/app_theme.dart';
import 'package:payflow/features/auth/models/auth_state.dart';
import 'package:payflow/features/auth/view_models/auth_view_model.dart';
import 'package:payflow/features/wallet/view_models/wallet_view_model.dart';
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
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('PayFlow Stage 8 Production Readiness & Reliability Tests', () {
    testWidgets('1. Session restoration preserves authenticated status on app launch', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('payflow_onboarding_completed', true);
      await prefs.setBool('payflow_is_authenticated', true);
      await prefs.setString('payflow_auth_phone', '+2348123456789');

      final container = ProviderContainer();
      await tester.pumpWidget(buildTestApp(container: container));
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();

      final authState = container.read(authViewModelProvider);
      expect(authState.status, equals(AuthStatus.authenticated));
      expect(authState.phoneNumber, equals('+2348123456789'));
    });

    testWidgets('2. Logout clears authenticated session and resets AuthState', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('payflow_onboarding_completed', true);
      await prefs.setBool('payflow_is_authenticated', true);

      final container = ProviderContainer();
      final authNotifier = container.read(authViewModelProvider.notifier);
      await authNotifier.checkInitialState();

      await authNotifier.logout();

      final updatedAuthState = container.read(authViewModelProvider);
      expect(updatedAuthState.status, equals(AuthStatus.unauthenticated));
      expect(updatedAuthState.phoneNumber, isNull);
      expect(prefs.getBool('payflow_is_authenticated'), isFalse);
    });

    test('3. Idempotency Guard rejects duplicate transaction reference processing', () async {
      final mockProvider = MockPaymentProvider();
      final service = PaymentService(
        customProviders: {mockProvider.providerType: mockProvider},
      );

      final request = PaymentRequest(
        transactionRef: 'PF-STAGE8-IDEM-001',
        amount: 4500.0,
        customerIdentifier: '@alexj',
        paymentType: 'transfer',
        description: 'Idempotent Transfer Test',
      );

      final firstAttempt = await service.processPayment(request);
      expect(firstAttempt.isConfirmed, isTrue);

      final secondAttempt = await service.processPayment(request);
      expect(secondAttempt.isConfirmed, isFalse);
      expect(secondAttempt.failureReason, contains('Idempotency Violation'));
    });

    test('4. Balance Safeguard: Wallet balance unchanged when provider initialization fails', () async {
      final walletVM = WalletViewModel();
      final initialBalance = walletVM.state.mainBalance;

      final failedProvider = MockPaymentProvider(shouldFailInitialization: true);
      final verif = await walletVM.processVerifiedFunding(
        amount: 15000.0,
        method: 'Debit Card',
        customProvider: failedProvider,
      );

      expect(verif.isConfirmed, isFalse);
      expect(walletVM.state.mainBalance, equals(initialBalance));
    });

    test('5. Balance Safeguard: Wallet balance unchanged when verification fails', () async {
      final walletVM = WalletViewModel();
      final initialBalance = walletVM.state.mainBalance;

      final unverifiedProvider = MockPaymentProvider(shouldFailVerification: true);
      final verif = await walletVM.processVerifiedTransfer(
        recipient: 'Michael Scott',
        transferType: 'PayFlow User',
        amount: 5000.0,
        customProvider: unverifiedProvider,
      );

      expect(verif.isConfirmed, isFalse);
      expect(walletVM.state.mainBalance, equals(initialBalance));
    });

    test('6. Wallet balance mutates ONLY after confirmed verification', () async {
      final walletVM = WalletViewModel();
      final initialBalance = walletVM.state.mainBalance;

      final verifiedProvider = MockPaymentProvider();
      final verif = await walletVM.processVerifiedFunding(
        amount: 25000.0,
        method: 'Bank Transfer',
        customProvider: verifiedProvider,
      );

      expect(verif.isConfirmed, isTrue);
      expect(walletVM.state.mainBalance, equals(initialBalance + 25000.0));
      expect(walletVM.state.transactions.first.title, contains('Fund Wallet'));
    });

    test('7. Insufficient balance validation prevents transfer and leaves balance untouched', () async {
      final walletVM = WalletViewModel();
      final initialBalance = walletVM.state.mainBalance;
      final initialTxCount = walletVM.state.transactions.length;

      final verif = await walletVM.processVerifiedTransfer(
        recipient: 'Sarah Connor',
        transferType: 'PayFlow User',
        amount: 99999999.0, // Exceeds balance
      );

      expect(verif.isConfirmed, isFalse);
      expect(walletVM.state.mainBalance, equals(initialBalance));
      expect(walletVM.state.transactions.length, equals(initialTxCount));
    });

    testWidgets('8. App Navigation Integrity across primary Shell destinations', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('payflow_onboarding_completed', true);
      await prefs.setBool('payflow_is_authenticated', true);

      final container = ProviderContainer();
      await tester.pumpWidget(buildTestApp(container: container));
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();

      // Home
      expect(find.text('Main Wallet Balance'), findsOneWidget);

      // Navigate to Wallet
      await tester.tap(find.text('Wallet'));
      await tester.pumpAndSettle();
      expect(find.text('My Wallet'), findsOneWidget);

      // Navigate to Transfer
      await tester.tap(find.text('Transfer'));
      await tester.pumpAndSettle();
      expect(find.text('Send Money'), findsOneWidget);

      // Navigate to Services
      await tester.tap(find.text('Services'));
      await tester.pumpAndSettle();
      expect(find.text('Pay Utilities'), findsOneWidget);

      // Navigate to Me
      await tester.tap(find.text('Me'));
      await tester.pumpAndSettle();
      expect(find.text('Me'), findsOneWidget);
    });
  });
}
