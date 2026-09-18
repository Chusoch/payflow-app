import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:payflow/core/config/env.dart';
import 'package:payflow/core/network/api_client.dart';
import 'package:payflow/core/payment/models/payment_status.dart';
import 'package:payflow/core/payment/providers/paystack_payment_provider.dart';
import 'package:payflow/core/payment/providers/vtpass_payment_provider.dart';
import 'package:payflow/core/theme/app_theme.dart';
import 'package:payflow/features/transfer/view_models/transfer_view_model.dart';
import 'package:payflow/features/transfer/views/transfer_screen.dart';
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
  late ApiClient originalApiClient;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    originalApiClient = defaultApiClient;
  });

  tearDown(() {
    defaultApiClient = originalApiClient;
    Env.setBackendApiBaseUrlForTesting(null);
  });

  group('Location 3: resolvePayFlowUser 404 & UI Error Propagation', () {
    test('resolvePayFlowUser sets error message and returns null on 404 without fabricating user', () async {
      final mockHttp = MockClient((request) async {
        if (request.url.path.contains('/v1/users/08099999999/profile')) {
          return http.Response(jsonEncode({'error': 'User not found'}), 404);
        }
        return http.Response(jsonEncode({'displayName': 'Real User'}), 200);
      });

      Env.setBackendApiBaseUrlForTesting('https://api.payflow.ng');
      defaultApiClient = ApiClient(baseUrl: 'https://api.payflow.ng', httpClient: mockHttp);

      final viewModel = TransferViewModel();
      final result = await viewModel.resolvePayFlowUser('08099999999');

      expect(result, isNull);
      expect(viewModel.state.resolvedAccountName, isNull);
      expect(viewModel.state.errorMessage, equals('No PayFlow user found with this number'));
    });

    testWidgets('TransferScreen displays error and blocks review sheet when recipient phone 404s', (tester) async {
      final mockHttp = MockClient((request) async {
        if (request.url.path.contains('/v1/users/08099999999/profile')) {
          return http.Response(jsonEncode({'error': 'User not found'}), 404);
        }
        return http.Response(jsonEncode({'displayName': 'Real User'}), 200);
      });

      Env.setBackendApiBaseUrlForTesting('https://api.payflow.ng');
      defaultApiClient = ApiClient(baseUrl: 'https://api.payflow.ng', httpClient: mockHttp);

      final container = ProviderContainer();
      await tester.pumpWidget(buildTestApp(child: const TransferScreen(), container: container));
      await tester.pumpAndSettle();

      // Enter mistyped recipient phone
      final recipientField = find.byType(TextField).first;
      await tester.enterText(recipientField, '08099999999');
      await tester.pumpAndSettle();

      // Enter transfer amount
      final amountField = find.byType(TextField).at(1);
      await tester.enterText(amountField, '2500');
      await tester.pumpAndSettle();

      // Click Continue Transfer
      final continueButton = find.text('Continue Transfer');
      await tester.ensureVisible(continueButton);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      // Confirm UI displays the real error message
      expect(find.text('No PayFlow user found with this number'), findsWidgets);

      // Confirm transfer flow blocked: Transfer Review Sheet is NOT open
      expect(find.text('Transfer Review'), findsNothing);
      expect(find.text('Confirm & Send'), findsNothing);
    });
  });

  group('Location 2: Dedicated Virtual Account (DVA) Error State & No Polling', () {
    testWidgets('FundWalletSheet displays real error UI and does not show fake account or poll on failure', (tester) async {
      final mockHttp = MockClient((request) async {
        if (request.url.path.contains('dedicated-account')) {
          return http.Response(
            jsonEncode({'message': 'Paystack dedicated virtual account service unavailable'}),
            503,
          );
        }
        return http.Response(jsonEncode({'status': 'error'}), 500);
      });

      Env.setBackendApiBaseUrlForTesting('https://api.payflow.ng');
      defaultApiClient = ApiClient(baseUrl: 'https://api.payflow.ng', httpClient: mockHttp);

      final container = ProviderContainer();
      await tester.pumpWidget(buildTestApp(child: const FundWalletSheet(), container: container));
      await tester.pumpAndSettle();

      // Select Bank Transfer method
      final bankTransferRadio = find.text('Bank Transfer');
      await tester.tap(bankTransferRadio);
      await tester.pumpAndSettle();

      // Enter top up amount
      final amountField = find.byType(TextField).first;
      await tester.enterText(amountField, '5000');
      await tester.pumpAndSettle();

      // Click Generate Virtual Account
      final generateBtn = find.text('Generate Virtual Account');
      await tester.ensureVisible(generateBtn);
      await tester.tap(generateBtn);
      await tester.pumpAndSettle();

      // Verify fake account synthesis is completely gone
      expect(find.text('9988223344'), findsNothing);
      expect(find.text('Wema Bank'), findsNothing);
      expect(find.text('I Have Transferred'), findsNothing);

      // Verify real error message is rendered with Retry Generation action
      expect(find.text('Paystack dedicated virtual account service unavailable'), findsOneWidget);
      expect(find.text('Retry Generation'), findsOneWidget);
    });
  });

  group('Location 4: Bank Account Resolution Error Handling', () {
    test('resolveBankAccount returns null and sets real error on failure instead of "Account Resolved"', () async {
      final mockHttp = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Could not resolve account name with destination bank'}),
          422,
        );
      });

      Env.setBackendApiBaseUrlForTesting('https://api.payflow.ng');
      defaultApiClient = ApiClient(baseUrl: 'https://api.payflow.ng', httpClient: mockHttp);

      final viewModel = TransferViewModel();
      final result = await viewModel.resolveBankAccount('0011223344', '058');

      expect(result, isNull);
      expect(viewModel.state.resolvedAccountName, isNull);
      expect(viewModel.state.errorMessage, equals('Could not resolve account name with destination bank'));
    });
  });

  group('Location 5: Payment Providers Return Failed PaymentResult on Non-200', () {
    test('PaystackPaymentProvider returns failed PaymentResult on HTTP non-200', () async {
      final mockHttp = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Invalid Paystack secret key'}),
          401,
        );
      });

      final provider = PaystackPaymentProvider(
        backendApiBaseUrl: 'https://api.payflow.ng',
        httpClient: mockHttp,
      );

      final result = await provider.initializePayment(
        const PaymentRequest(
          transactionRef: 'PF-TEST-PAYSTACK-001',
          amount: 5000.0,
          customerIdentifier: 'customer@payflow.ng',
          paymentType: 'fund_wallet',
          description: 'Fund Wallet via Paystack',
        ),
      );

      expect(result.status, equals(PaymentStatus.failed));
      expect(result.failureReason, equals('Invalid Paystack secret key'));
    });

    test('VTPassPaymentProvider returns failed PaymentResult on HTTP non-200', () async {
      final mockHttp = MockClient((request) async {
        return http.Response(
          jsonEncode({'response_description': 'System busy. Service temporarily down'}),
          503,
        );
      });

      final provider = VTPassPaymentProvider(
        backendApiBaseUrl: 'https://api.payflow.ng',
        httpClient: mockHttp,
      );

      final result = await provider.initializePayment(
        const PaymentRequest(
          transactionRef: 'PF-TEST-VTPASS-001',
          amount: 1000.0,
          customerIdentifier: '08012345678',
          paymentType: 'airtime',
          description: 'MTN Airtime Purchase',
        ),
      );

      expect(result.status, equals(PaymentStatus.failed));
      expect(result.failureReason, equals('System busy. Service temporarily down'));
    });
  });
}
