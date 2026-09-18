import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payflow/core/theme/app_theme.dart';
import 'package:payflow/features/transfer/view_models/transfer_view_model.dart';
import 'package:payflow/features/transfer/views/transfer_screen.dart';
import 'package:payflow/features/wallet/view_models/wallet_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget buildTestTransferApp({required ProviderContainer container}) {
  return UncontrolledProviderScope(
    container: container,
    child: Builder(
      builder: (context) {
        return MaterialApp(
          theme: AppTheme.lightTheme(context),
          home: const TransferScreen(),
        );
      },
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('PayFlow Stage 5 Money Transfer Workflows Tests', () {
    testWidgets('1. Transfer type switching updates ViewModel state', (tester) async {
      final container = ProviderContainer();
      await tester.pumpWidget(buildTestTransferApp(container: container));
      await tester.pumpAndSettle();

      expect(container.read(transferViewModelProvider).selectedTransferType, equals('PayFlow User'));

      await tester.tap(find.text('Bank Account'));
      await tester.pumpAndSettle();
      expect(container.read(transferViewModelProvider).selectedTransferType, equals('Bank Account'));
    });

    testWidgets('2. Tapping beneficiary Sarah Connor populates recipient field', (tester) async {
      final container = ProviderContainer();
      await tester.pumpWidget(buildTestTransferApp(container: container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sarah'));
      await tester.pumpAndSettle();

      final textField = find.byType(TextField).first;
      expect((tester.widget(textField) as TextField).controller?.text, equals('08012345678'));
    });

    testWidgets('3. Amount exceeding wallet balance shows insufficient balance validation error', (tester) async {
      final container = ProviderContainer();
      await tester.pumpWidget(buildTestTransferApp(container: container));
      await tester.pumpAndSettle();

      // Populate recipient
      await tester.tap(find.text('Sarah'));
      await tester.pumpAndSettle();

      // Enter amount larger than balance (balance is ₦245,850.75)
      await tester.enterText(find.byType(TextField).at(1), '500000');
      await tester.pumpAndSettle();

      final buttonFinder = find.text('Continue Transfer');
      await tester.ensureVisible(buttonFinder);
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      expect(find.textContaining('Insufficient balance'), findsOneWidget);
    });

    testWidgets('4. Successful transfer updates WalletViewModel balance and prepends transaction record', (tester) async {
      final container = ProviderContainer();
      final walletNotifier = container.read(walletViewModelProvider.notifier);
      final initialBalance = container.read(walletViewModelProvider).mainBalance;

      final refCode = walletNotifier.sendMoney(
        recipient: 'Sarah Connor',
        transferType: 'PayFlow User',
        amount: 5000.00,
        note: 'Lunch payment',
      );

      final updatedWallet = container.read(walletViewModelProvider);
      expect(updatedWallet.mainBalance, equals(initialBalance - 5000.00));
      expect(refCode, startsWith('PF-TRF-'));

      final latestTx = updatedWallet.transactions.first;
      expect(latestTx.title, equals('Transfer to Sarah Connor'));
      expect(latestTx.amount, equals(5000.00));
      expect(latestTx.isCredit, isFalse);
      expect(latestTx.reference, equals(refCode));
    });

    testWidgets('5. Recipient clearing immediately resets verifiedRecipient to null and hides banner', (tester) async {
      final container = ProviderContainer();
      await tester.pumpWidget(buildTestTransferApp(container: container));
      await tester.pumpAndSettle();

      final recipientField = find.byType(TextField).first;

      // Type valid number to trigger verification
      await tester.enterText(recipientField, '08012345678');
      await tester.pumpAndSettle();

      expect(container.read(transferViewModelProvider).verifiedRecipient, equals('Sarah Connor'));
      expect(find.text('Account Verified: Sarah Connor'), findsOneWidget);

      // Clear input
      await tester.enterText(recipientField, '');
      await tester.pumpAndSettle();

      expect(container.read(transferViewModelProvider).verifiedRecipient, isNull);
      expect(container.read(transferViewModelProvider).resolvedAccountName, isNull);
      expect(find.textContaining('Account Verified'), findsNothing);
    });

    testWidgets('6. resetTransferState resets verifiedRecipient, selectedBank, and amount', (tester) async {
      final container = ProviderContainer();
      final notifier = container.read(transferViewModelProvider.notifier);

      notifier.setSelectedBank('Zenith Bank', '057');
      notifier.setAmount(15000.0);
      await notifier.resolveBankAccount('0123456789', '058');

      expect(container.read(transferViewModelProvider).selectedBank, equals('Zenith Bank'));
      expect(container.read(transferViewModelProvider).amount, equals(15000.0));
      expect(container.read(transferViewModelProvider).verifiedRecipient, equals('ALEX CHUKWU'));

      notifier.resetTransferState();

      final resetState = container.read(transferViewModelProvider);
      expect(resetState.verifiedRecipient, isNull);
      expect(resetState.resolvedAccountName, isNull);
      expect(resetState.amount, isNull);
      expect(resetState.selectedBank, equals('GTBank'));
      expect(resetState.selectedBankCode, equals('058'));
    });

    testWidgets('7. In Bank Account mode, entering 10-digit NUBAN resolves account name and backspacing removes banner', (tester) async {
      final container = ProviderContainer();
      await tester.pumpWidget(buildTestTransferApp(container: container));
      await tester.pumpAndSettle();

      // Switch to Bank Account mode
      await tester.tap(find.text('Bank Account'));
      await tester.pumpAndSettle();

      final recipientField = find.byType(TextField).first;

      // Enter 10-digit NUBAN
      await tester.enterText(recipientField, '0123456789');
      await tester.pumpAndSettle();

      expect(container.read(transferViewModelProvider).verifiedRecipient, equals('ALEX CHUKWU'));
      expect(find.text('Account Verified: ALEX CHUKWU'), findsOneWidget);

      // Backspace to 9 digits
      await tester.enterText(recipientField, '012345678');
      await tester.pumpAndSettle();

      expect(container.read(transferViewModelProvider).verifiedRecipient, isNull);
      expect(find.textContaining('Account Verified'), findsNothing);
    });
  });
}
