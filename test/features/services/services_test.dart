import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payflow/core/payment/providers/payment_provider.dart';
import 'package:payflow/core/theme/app_theme.dart';
import 'package:payflow/features/services/views/services_screen.dart';
import 'package:payflow/features/wallet/view_models/wallet_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget buildTestServicesApp({required ProviderContainer container}) {
  return UncontrolledProviderScope(
    container: container,
    child: Builder(
      builder: (context) {
        return MaterialApp(
          theme: AppTheme.lightTheme(context),
          home: const ServicesScreen(),
        );
      },
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('PayFlow Stage 6 Services & Utility Payments Tests', () {
    testWidgets('1. ServicesScreen renders 4 primary service cards', (tester) async {
      final container = ProviderContainer();
      await tester.pumpWidget(buildTestServicesApp(container: container));
      await tester.pumpAndSettle();

      expect(find.text('Pay Utilities'), findsOneWidget);
      expect(find.text('Airtime'), findsOneWidget);
      expect(find.text('Mobile Data'), findsOneWidget);
      expect(find.text('Electricity'), findsOneWidget);
      expect(find.text('Cable TV'), findsOneWidget);
    });

    testWidgets('2. WalletViewModel.payService deducts balance and prepends transaction', (tester) async {
      final container = ProviderContainer();
      final walletNotifier = container.read(walletViewModelProvider.notifier);
      final initialBalance = container.read(walletViewModelProvider).mainBalance;

      final verification = await walletNotifier.payService(
        title: 'MTN Airtime (08123456789)',
        category: 'Bills',
        amount: 1000.00,
        identifier: '08123456789',
        referencePrefix: 'PF-AIR-',
        providerType: PaymentProviderType.mock,
      );

      final updatedState = container.read(walletViewModelProvider);
      expect(verification.isConfirmed, isTrue);
      expect(verification.transactionRef, startsWith('PF-AIR-'));
      expect(updatedState.mainBalance, equals(initialBalance - 1000.00));
      expect(updatedState.transactions.first.title, equals('MTN Airtime (08123456789)'));
      expect(updatedState.transactions.first.amount, equals(1000.00));
      expect(updatedState.transactions.first.isCredit, isFalse);
    });

    testWidgets('3. WalletViewModel.payService returns failure on insufficient balance', (tester) async {
      final container = ProviderContainer();
      final walletNotifier = container.read(walletViewModelProvider.notifier);
      final initialBalance = container.read(walletViewModelProvider).mainBalance;
      final initialTxLength = container.read(walletViewModelProvider).transactions.length;

      final verification = await walletNotifier.payService(
        title: 'Electricity Bill',
        category: 'Bills',
        amount: 9999999.00, // Exceeds balance
        identifier: '0192837465',
        referencePrefix: 'PF-ELEC-',
        providerType: PaymentProviderType.mock,
      );

      final currentState = container.read(walletViewModelProvider);
      expect(verification.isConfirmed, isFalse);
      expect(currentState.mainBalance, equals(initialBalance));
      expect(currentState.transactions.length, equals(initialTxLength));
    });

    testWidgets('4. Tapping Airtime opens AirtimeFlowSheet', (tester) async {
      final container = ProviderContainer();
      await tester.pumpWidget(buildTestServicesApp(container: container));
      await tester.pumpAndSettle();

      final airtimeCard = find.text('Airtime');
      await tester.ensureVisible(airtimeCard);
      await tester.tap(airtimeCard);
      await tester.pumpAndSettle();

      expect(find.text('Buy Airtime'), findsOneWidget);
      expect(find.text('Select Network'), findsOneWidget);
      expect(find.text('08123456789'), findsOneWidget);
    });

    testWidgets('5. Tapping Mobile Data opens MobileDataFlowSheet with plan catalog', (tester) async {
      final container = ProviderContainer();
      await tester.pumpWidget(buildTestServicesApp(container: container));
      await tester.pumpAndSettle();

      final dataCard = find.text('Mobile Data');
      await tester.ensureVisible(dataCard);
      await tester.tap(dataCard);
      await tester.pumpAndSettle();

      expect(find.text('Buy Mobile Data'), findsOneWidget);
      expect(find.text('Select Data Plan'), findsOneWidget);
      expect(find.textContaining('1.5GB'), findsOneWidget);
    });

    testWidgets('6. Tapping Electricity opens ElectricityFlowSheet with Disco & Meter type', (tester) async {
      final container = ProviderContainer();
      await tester.pumpWidget(buildTestServicesApp(container: container));
      await tester.pumpAndSettle();

      final elecCard = find.text('Electricity');
      await tester.ensureVisible(elecCard);
      await tester.tap(elecCard);
      await tester.pumpAndSettle();

      expect(find.text('Pay Electricity'), findsOneWidget);
      expect(find.text('Ikeja Electric'), findsOneWidget);
      expect(find.text('Prepaid'), findsOneWidget);
    });

    testWidgets('7. Tapping Cable TV opens CableTvFlowSheet with packages', (tester) async {
      final container = ProviderContainer();
      await tester.pumpWidget(buildTestServicesApp(container: container));
      await tester.pumpAndSettle();

      final cableCard = find.text('Cable TV');
      await tester.ensureVisible(cableCard);
      await tester.tap(cableCard);
      await tester.pumpAndSettle();

      expect(find.text('Cable TV Subscription'), findsOneWidget);
      expect(find.text('DSTV Yanga'), findsOneWidget);
    });

    testWidgets('8. Electricity payment generates token and logs token on transaction item', (tester) async {
      final container = ProviderContainer();
      final walletNotifier = container.read(walletViewModelProvider.notifier);

      const token = '4920-1849-2048-1039';
      final verification = await walletNotifier.payService(
        title: 'Electricity (Ikeja Electric)',
        category: 'Electricity',
        amount: 5000.00,
        identifier: '0192837465 (Prepaid)',
        referencePrefix: 'PF-ELEC-',
        token: token,
        narration: 'Prepaid Token Recharge',
        providerType: PaymentProviderType.mock,
      );

      final state = container.read(walletViewModelProvider);
      expect(verification.isConfirmed, isTrue);
      expect(verification.transactionRef, startsWith('PF-ELEC-'));
      expect(state.transactions.first.token, equals('4920-1849-2048-1039'));
      expect(state.transactions.first.narration, equals('Prepaid Token Recharge'));
    });

    testWidgets('9. Idempotency Guard: Rapid duplicate payment submission debits wallet ONLY ONCE', (tester) async {
      final container = ProviderContainer();
      final walletNotifier = container.read(walletViewModelProvider.notifier);
      final initialBalance = container.read(walletViewModelProvider).mainBalance;
      const refCode = 'PF-DUP-TEST-999';

      // First Submission - Should succeed
      final res1 = await walletNotifier.payService(
        title: 'MTN Data Subscription',
        category: 'Data',
        amount: 2000.00,
        identifier: '08012345678',
        customReference: refCode,
        providerType: PaymentProviderType.mock,
      );

      expect(res1.isConfirmed, isTrue);
      final balanceAfterFirst = container.read(walletViewModelProvider).mainBalance;
      expect(balanceAfterFirst, equals(initialBalance - 2000.00));

      // Second Duplicate Submission - Must fail idempotency check
      final res2 = await walletNotifier.payService(
        title: 'MTN Data Subscription',
        category: 'Data',
        amount: 2000.00,
        identifier: '08012345678',
        customReference: refCode,
        providerType: PaymentProviderType.mock,
      );

      expect(res2.isConfirmed, isFalse);
      expect(res2.failureReason, contains('Idempotency Violation'));

      // Final Assertions: Balance was debited ONLY ONCE (2000.00 total)
      final finalBalance = container.read(walletViewModelProvider).mainBalance;
      expect(finalBalance, equals(initialBalance - 2000.00));
      expect(container.read(walletViewModelProvider).transactions.where((tx) => tx.reference == refCode).length, equals(1));
    });

    testWidgets('10. ServiceReviewSheet shows real payment failure error banner on error without throwing widget-lifecycle error', (tester) async {
      final container = ProviderContainer();
      await tester.pumpWidget(buildTestServicesApp(container: container));
      await tester.pumpAndSettle();

      final airtimeCard = find.text('Airtime');
      await tester.ensureVisible(airtimeCard);
      await tester.tap(airtimeCard);
      await tester.pumpAndSettle();

      // Enter amount exceeding balance to trigger review sheet
      final amountField = find.widgetWithText(TextField, '0.00');
      await tester.enterText(amountField, '99999999');
      await tester.pumpAndSettle();

      final continueBtn = find.text('Continue to Review');
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      expect(find.text('Review Payment'), findsOneWidget);
      expect(find.text('Insufficient wallet balance for this purchase.'), findsOneWidget);
    });

    testWidgets('11. Successful service payment shows immediate ServiceResultSheet confirmation', (tester) async {
      final container = ProviderContainer();
      await tester.pumpWidget(buildTestServicesApp(container: container));
      await tester.pumpAndSettle();

      // Open Airtime sheet
      final airtimeCard = find.text('Airtime');
      await tester.ensureVisible(airtimeCard);
      await tester.tap(airtimeCard);
      await tester.pumpAndSettle();

      // Enter valid amount
      final amountField = find.widgetWithText(TextField, '0.00');
      await tester.enterText(amountField, '500');
      await tester.pumpAndSettle();

      // Tap Continue to Review
      final continueBtn = find.text('Continue to Review');
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      expect(find.text('Review Payment'), findsOneWidget);

      // Tap Confirm & Pay
      final confirmBtn = find.text('Confirm & Pay');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Enter 4-digit PIN '1234' on TransactionPinBottomSheet
      if (find.text('Enter Transaction PIN').evaluate().isNotEmpty) {
        await tester.tap(find.text('1'));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(find.text('2'));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(find.text('3'));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(find.text('4'));
        await tester.pumpAndSettle();
      }

      // Verify ServiceResultSheet appears immediately with success confirmation
      expect(find.text('Payment Successful!'), findsOneWidget);
      expect(find.text('₦500.00'), findsOneWidget);
      expect(find.text('Airtime Recharge • MTN'), findsOneWidget);
      expect(find.text('Transaction Reference'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('12. Successful electricity payment shows immediate ServiceResultSheet confirmation with token display step', (tester) async {
      final container = ProviderContainer();
      await tester.pumpWidget(buildTestServicesApp(container: container));
      await tester.pumpAndSettle();

      // Open Electricity sheet
      final elecCard = find.text('Electricity');
      await tester.ensureVisible(elecCard);
      await tester.tap(elecCard);
      await tester.pumpAndSettle();

      // Verify meter number first
      final verifyBtn = find.text('Verify Meter Number');
      await tester.tap(verifyBtn);
      await tester.pumpAndSettle();

      expect(find.text('CHUKWUMA UGOBUEZE'), findsOneWidget);

      // Enter valid amount
      final amountField = find.widgetWithText(TextField, '0.00');
      await tester.enterText(amountField, '2000');
      await tester.pumpAndSettle();

      // Tap Continue to Review
      final continueBtn = find.text('Continue to Review');
      await tester.ensureVisible(continueBtn);
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      expect(find.text('Review Payment'), findsOneWidget);
      expect(find.text('Ikeja Electric (CHUKWUMA UGOBUEZE)'), findsOneWidget);

      // Tap Confirm & Pay
      final confirmBtn = find.text('Confirm & Pay');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Enter 4-digit PIN '1234' on TransactionPinBottomSheet
      if (find.text('Enter Transaction PIN').evaluate().isNotEmpty) {
        await tester.tap(find.text('1'));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(find.text('2'));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(find.text('3'));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(find.text('4'));
        await tester.pumpAndSettle();
      }

      // Verify ServiceResultSheet appears immediately with success confirmation & token display step
      expect(find.text('Payment Successful!'), findsOneWidget);
      expect(find.text('₦2000.00'), findsOneWidget);
      expect(find.text('Electricity Bill Payment • Ikeja Electric (CHUKWUMA UGOBUEZE)'), findsOneWidget);
      expect(find.text('Electricity Token'), findsOneWidget);
      expect(find.textContaining('4920-1849-'), findsOneWidget);
      expect(find.text('Transaction Reference'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });
  });
}
