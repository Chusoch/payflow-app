import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:payflow/core/network/api_client.dart';
import 'package:payflow/core/theme/app_theme.dart';
import 'package:payflow/features/home/views/home_screen.dart';
import 'package:payflow/features/wallet/view_models/wallet_view_model.dart';
import 'package:payflow/features/wallet/widgets/fund_wallet_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget buildTestApp({required Widget child, required ProviderContainer container}) {
  return UncontrolledProviderScope(
    container: container,
    child: Builder(
      builder: (context) {
        return MaterialApp(
          theme: AppTheme.lightTheme(context),
          home: Scaffold(body: child),
        );
      },
    ),
  );
}

void main() {
  late ApiClient originalClient;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    originalClient = defaultApiClient;
  });

  tearDown(() {
    defaultApiClient = originalClient;
  });

  group('Live Paystack Wallet Funding Flow Tests', () {
    testWidgets('Dashboard Add Money button opens FundWalletSheet', (tester) async {
      final container = ProviderContainer();

      await tester.pumpWidget(
        buildTestApp(child: const HomeScreen(), container: container),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final addMoneyBtn = find.byKey(const Key('add_money_button'));
      expect(addMoneyBtn, findsOneWidget);
      expect(find.text('Add Money').first, findsOneWidget);

      await tester.tap(addMoneyBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(FundWalletSheet), findsOneWidget);
      expect(find.text('Fund Wallet'), findsOneWidget);
    });

    testWidgets('Initializes via /v1/wallet/initialize-funding and verifies via /v1/wallet/verify-funding', (tester) async {
      bool initializeCalled = false;
      bool verifyCalled = false;
      String? sentReference;

      final mockHttp = MockClient((request) async {
        if (request.url.path == '/v1/wallet/initialize-funding') {
          initializeCalled = true;
          final body = jsonDecode(request.body);
          expect(body['amount'], equals(2500.0));
          expect(body['phoneNumber'], isNotEmpty);

          return http.Response(
            jsonEncode({
              'success': true,
              'status': true,
              'authorization_url': 'https://checkout.paystack.com/pf-test-auth-url',
              'access_code': 'acc_test_123',
              'reference': 'PF_FUND_1789220000_2348011111111',
              'data': {
                'authorization_url': 'https://checkout.paystack.com/pf-test-auth-url',
                'access_code': 'acc_test_123',
                'reference': 'PF_FUND_1789220000_2348011111111',
              },
            }),
            200,
          );
        }

        if (request.url.path == '/v1/wallet/verify-funding') {
          verifyCalled = true;
          final body = jsonDecode(request.body);
          sentReference = body['reference'];
          expect(body['reference'], startsWith('PF_FUND_'));

          return http.Response(
            jsonEncode({
              'success': true,
              'status': 'success',
              'reference': body['reference'],
              'walletBalance': 350000, // ₦3,500
              'amount': 250000,
            }),
            200,
          );
        }

        return http.Response('Not found', 404);
      });

      defaultApiClient = ApiClient(baseUrl: 'https://api.payflow.ng', httpClient: mockHttp);

      final container = ProviderContainer();
      final initialBalance = container.read(walletViewModelProvider).mainBalance;

      await tester.pumpWidget(
        buildTestApp(child: const FundWalletSheet(), container: container),
      );
      await tester.pumpAndSettle();

      // Step 1: Type ₦2,500 and proceed
      await tester.enterText(find.byType(TextField), '2500');
      await tester.tap(find.text('Review Top Up'));
      await tester.pumpAndSettle();

      // Step 2: Tap Pay with Paystack
      await tester.tap(find.text('Pay with Paystack'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(initializeCalled, isTrue);
      expect(find.text('Complete Card Payment'), findsOneWidget);

      // Verify wallet not yet credited during pending checkout
      expect(container.read(walletViewModelProvider).mainBalance, equals(initialBalance));

      // User returns after payment and taps "I Have Paid"
      await tester.tap(find.text('I Have Paid'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(verifyCalled, isTrue);
      expect(sentReference, equals('PF_FUND_1789220000_2348011111111'));

      // Step 3: Success state is displayed
      expect(find.text('Top Up Successful!'), findsOneWidget);

      // Balance credited by exactly ₦2,500
      final updatedBalance = container.read(walletViewModelProvider).mainBalance;
      expect(updatedBalance, equals(initialBalance + 2500.0));
    });
  });
}
