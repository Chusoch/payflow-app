import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payflow/core/theme/app_colors.dart';
import 'package:payflow/core/theme/app_theme.dart';
import 'package:payflow/core/widgets/payflow_card.dart';
import 'package:payflow/features/wallet/view_models/wallet_view_model.dart';
import 'package:payflow/features/wallet/views/wallet_screen.dart';
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

  group('PayFlow Wallet Experience Tests', () {
    testWidgets('1. Renders main wallet balance and transaction history', (tester) async {
      final container = ProviderContainer();
      await tester.pumpWidget(buildTestWalletApp(container: container));
      await tester.pumpAndSettle();

      expect(find.text('Main Wallet Balance'), findsOneWidget);
      expect(find.text('₦245850.75'), findsOneWidget);
      expect(find.text('Transaction History'), findsOneWidget);
    });

    testWidgets('2. Fund Wallet increases balance and adds transaction record in state', (tester) async {
      final container = ProviderContainer();
      final notifier = container.read(walletViewModelProvider.notifier);

      final initialBalance = container.read(walletViewModelProvider).mainBalance;
      notifier.fundWallet(amount: 10000.00, method: 'Bank Transfer');

      final updatedState = container.read(walletViewModelProvider);
      expect(updatedState.mainBalance, equals(initialBalance + 10000.00));
      expect(updatedState.transactions.first.title, contains('Fund Wallet (Bank Transfer)'));
      expect(updatedState.transactions.first.amount, equals(10000.00));
      expect(updatedState.transactions.first.isCredit, isTrue);
    });

    testWidgets('3. Hero balance card renders with primaryGradient and white text (preventing blank/invisible rendering)', (tester) async {
      final container = ProviderContainer();
      await tester.pumpWidget(buildTestWalletApp(container: container));
      await tester.pumpAndSettle();

      // Find the first PayFlowCard which is the hero balance card
      final heroCardFinder = find.byType(PayFlowCard).first;
      expect(heroCardFinder, findsOneWidget);

      final payFlowCard = tester.widget<PayFlowCard>(heroCardFinder);
      expect(payFlowCard.variant, equals(PayFlowCardVariant.gradient));
      expect(payFlowCard.gradient, equals(AppColors.primaryGradient));

      // Verify the underlying Container has gradient decoration and no white background
      final containerFinder = find.descendant(
        of: heroCardFinder,
        matching: find.byType(Container),
      ).first;
      final containerWidget = tester.widget<Container>(containerFinder);
      final decoration = containerWidget.decoration as BoxDecoration;
      expect(decoration.gradient, equals(AppColors.primaryGradient));
      expect(decoration.color, isNull);

      // Verify text contrast: balance text is white, contrasting on gradient
      final balanceTextFinder = find.text('₦245850.75');
      final textWidget = tester.widget<Text>(balanceTextFinder);
      expect(textWidget.style?.color, equals(Colors.white));
    });

    testWidgets('4. End-to-end top-up flow updates and renders the actual new balance on WalletScreen', (tester) async {
      final container = ProviderContainer();
      await tester.pumpWidget(buildTestWalletApp(container: container));
      await tester.pumpAndSettle();

      // 1. Initial balance is displayed on screen
      expect(find.text('₦245850.75'), findsOneWidget);

      // 2. Perform ₦1,000 top up (as in user scenario)
      final notifier = container.read(walletViewModelProvider.notifier);
      notifier.fundWallet(amount: 1000.00, method: 'Debit Card');

      // 3. Re-render UI
      await tester.pumpAndSettle();

      // 4. Confirm real balance number is rendered on WalletScreen
      expect(find.text('₦245850.75'), findsNothing);
      expect(find.text('₦246850.75'), findsOneWidget);

      // 5. Confirm transaction history reflects the ₦1000 credit
      expect(find.text('Fund Wallet (Debit Card)'), findsOneWidget);
      expect(find.text('+₦1000.00'), findsOneWidget);
    });
  });
}

