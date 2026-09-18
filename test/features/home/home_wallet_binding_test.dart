import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payflow/core/config/env.dart';
import 'package:payflow/features/home/view_models/home_view_model.dart';
import 'package:payflow/features/home/views/home_screen.dart';
import 'package:payflow/features/wallet/repositories/wallet_repository.dart';
import 'package:payflow/features/wallet/view_models/wallet_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeWalletRepository implements WalletRepository {
  double balance = 50000.0;
  List<TransactionItem> transactions = [];
  bool getTransactionsCalled = false;
  bool getBalanceCalled = false;

  @override
  Future<double?> getBalance() async {
    getBalanceCalled = true;
    return balance;
  }

  @override
  Future<List<TransactionItem>> getTransactions() async {
    getTransactionsCalled = true;
    return transactions;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Home and Wallet Integration & Hydration Tests', () {
    test('WalletState provides balance and recentTransactions getters', () {
      final txns = List.generate(
        10,
        (i) => TransactionItem(
          id: 'tx_$i',
          title: 'Test $i',
          category: 'Transfer',
          amount: 100.0 * (i + 1),
          timestamp: DateTime.now(),
          isCredit: i % 2 == 0,
          status: 'Completed',
        ),
      );

      final state = WalletState(mainBalance: 75432.50, transactions: txns);

      expect(state.balance, equals(75432.50));
      expect(state.recentTransactions.length, equals(5));
      expect(state.recentTransactions.first.id, equals('tx_0'));
      expect(state.recentTransactions.last.id, equals('tx_4'));
    });

    test('HomeViewModel.refresh delegates to WalletViewModel.refreshWallet', () async {
      final fakeRepo = FakeWalletRepository();
      fakeRepo.balance = 85000.0;

      final container = ProviderContainer(
        overrides: [
          walletRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );

      final homeNotifier = container.read(homeViewModelProvider.notifier);
      await homeNotifier.refresh();

      // Ensure wallet was refreshed as part of home refresh
      final walletState = container.read(walletViewModelProvider);
      expect(walletState.balance, equals(Env.isMockMode ? 245850.75 : 85000.0));
    });

    testWidgets('HomeScreen initializes and displays balance from WalletViewModel', (tester) async {
      final container = ProviderContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final walletState = container.read(walletViewModelProvider);
      expect(find.text('₦${walletState.balance.toStringAsFixed(2)}'), findsOneWidget);
    });
  });
}
