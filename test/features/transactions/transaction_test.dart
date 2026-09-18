import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payflow/core/theme/app_theme.dart';
import 'package:payflow/features/home/models/transaction_item.dart';
import 'package:payflow/features/wallet/view_models/wallet_view_model.dart';
import 'package:payflow/features/wallet/views/wallet_screen.dart';
import 'package:payflow/features/wallet/widgets/transaction_detail_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget buildTestWalletApp({required ProviderContainer container}) {
  return UncontrolledProviderScope(
    container: container,
    child: Builder(
      builder: (context) {
        return MaterialApp(
          theme: AppTheme.lightTheme(context),
          home: const WalletScreen(),
        );
      },
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('PayFlow Stage 5 Transaction History & Detail Tests', () {
    testWidgets('1. Wallet renders transaction history list', (tester) async {
      final container = ProviderContainer();
      await tester.pumpWidget(buildTestWalletApp(container: container));
      await tester.pumpAndSettle();

      expect(find.text('Transaction History'), findsOneWidget);
      expect(find.text('Electricity Token Purchase'), findsOneWidget);
      expect(find.text('Salary Deposit - TechCorp'), findsOneWidget);
    });

    testWidgets('2. Transaction history filters work (Money In / Money Out)', (tester) async {
      final container = ProviderContainer();
      final notifier = container.read(walletViewModelProvider.notifier);

      expect(container.read(walletViewModelProvider).activeFilter, equals('All'));

      notifier.setTransactionFilter('Money In');
      final moneyInTxs = container.read(walletViewModelProvider).filteredTransactions;
      expect(moneyInTxs.every((tx) => tx.isCredit), isTrue);

      notifier.setTransactionFilter('Money Out');
      final moneyOutTxs = container.read(walletViewModelProvider).filteredTransactions;
      expect(moneyOutTxs.every((tx) => !tx.isCredit), isTrue);
    });

    testWidgets('3. Tapping transaction item opens Transaction Detail Sheet', (tester) async {
      final container = ProviderContainer();
      await tester.pumpWidget(buildTestWalletApp(container: container));
      await tester.pumpAndSettle();

      // Scroll to transaction history list
      final txFinder = find.text('Electricity Token Purchase');
      await tester.ensureVisible(txFinder);
      await tester.tap(txFinder);
      await tester.pumpAndSettle();

      expect(find.text('Transaction Reference'), findsOneWidget);
      expect(find.text('PF-ELE-948201'), findsOneWidget);
      expect(find.text('Electricity'), findsAtLeast(1));
    });

    testWidgets('4. TransactionDetailSheet renders details correctly', (tester) async {
      final tx = TransactionItem(
        id: 'tx_test_99',
        title: 'Electricity Bill',
        category: 'Utilities',
        amount: 5500.00,
        timestamp: DateTime.now(),
        isCredit: false,
        status: 'Completed',
        reference: 'PF-TXN-999000',
        recipientOrSender: 'IKEDC Electric',
        transferType: 'Bill Payment',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => TransactionDetailSheet.show(context, tx),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('-₦5500.00'), findsOneWidget);
      expect(find.text('Electricity Bill'), findsOneWidget);
      expect(find.text('PF-TXN-999000'), findsOneWidget);
      expect(find.text('IKEDC Electric'), findsOneWidget);
    });

    test('5. getTransactionTitle formats directional narrative correctly for sender and recipient', () {
      const userAId = '+2348011111111';
      const userBId = '+2348022222222';

      // Outgoing transaction from User A to User B
      final outgoingTxn = Transaction(
        id: 'tx_out_1',
        title: 'Transfer to Chukwuma Sochima',
        category: 'transfer',
        amount: 5000.0,
        timestamp: DateTime.now(),
        isCredit: false,
        status: 'Completed',
        senderId: userAId,
        recipientId: userBId,
        senderName: 'Ugobueze User',
        recipientName: 'Chukwuma Sochima',
      );

      // Incoming transaction to User B from User A
      final incomingTxn = Transaction(
        id: 'tx_in_1',
        title: 'Transfer from Ugobueze User',
        category: 'transfer',
        amount: 5000.0,
        timestamp: DateTime.now(),
        isCredit: true,
        status: 'Completed',
        senderId: userAId,
        recipientId: userBId,
        senderName: 'Ugobueze User',
        recipientName: 'Chukwuma Sochima',
      );

      // User A perspective (Debit / Outgoing)
      expect(getTransactionTitle(outgoingTxn, userAId), equals('Transfer to Chukwuma Sochima'));
      expect(outgoingTxn.getFormattedTitle(userAId), equals('Transfer to Chukwuma Sochima'));

      // User B perspective (Credit / Incoming)
      expect(getTransactionTitle(incomingTxn, userBId), equals('Transfer from Ugobueze User'));
      expect(incomingTxn.getFormattedTitle(userBId), equals('Transfer from Ugobueze User'));

      // Fallback to "Recipient" and "Sender" when names are empty
      final unnamedOutTxn = Transaction(
        id: 'tx_out_empty',
        title: '',
        category: 'transfer',
        amount: 1000.0,
        timestamp: DateTime.now(),
        isCredit: false,
        status: 'Completed',
        senderId: userAId,
        recipientId: userBId,
      );
      final unnamedInTxn = Transaction(
        id: 'tx_in_empty',
        title: '',
        category: 'transfer',
        amount: 1000.0,
        timestamp: DateTime.now(),
        isCredit: true,
        status: 'Completed',
        senderId: userAId,
        recipientId: userBId,
      );
      expect(getTransactionTitle(unnamedOutTxn, userAId), equals('Transfer to Recipient'));
      expect(getTransactionTitle(unnamedInTxn, userBId), equals('Transfer from Sender'));

      // Non-transfer categories retain standard title/description
      final airtimeTxn = Transaction(
        id: 'tx_airtime_1',
        title: 'MTN Airtime Topup',
        category: 'airtime',
        amount: 2000.0,
        timestamp: DateTime.now(),
        isCredit: false,
        status: 'Completed',
      );
      expect(getTransactionTitle(airtimeTxn, userAId), equals('MTN Airtime Topup'));
    });
  });
}
