import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:payflow/core/network/api_client.dart';
import 'package:payflow/core/payment/models/payment_status.dart';
import 'package:payflow/core/payment/providers/payment_provider.dart';
import 'package:payflow/core/payment/services/payment_service.dart';
import 'package:payflow/core/theme/app_theme.dart';
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

class FakePaystackProvider implements PaymentProvider {
  @override
  PaymentProviderType get providerType => PaymentProviderType.paystack;

  @override
  Future<PaymentResult> initializePayment(PaymentRequest request) async {
    return PaymentResult(
      transactionRef: request.transactionRef,
      providerRef: 'PST-12345',
      amount: request.amount,
      status: PaymentStatus.pending,
      timestamp: DateTime.now(),
      rawResponse: {
        'authorizationUrl': 'https://checkout.paystack.com/test-checkout-url',
        'status': 'success',
      },
    );
  }

  @override
  Future<PaymentVerification> verifyPayment(String transactionRef, {String? providerRef}) async {
    return PaymentVerification(
      transactionRef: transactionRef,
      providerRef: providerRef,
      amountPaid: 1000.0,
      status: PaymentStatus.successful,
      isConfirmed: true,
      verifiedAt: DateTime.now(),
    );
  }
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

  group('Debit Card Paystack Checkout & Verification Integrity Tests', () {
    test('1. PaymentService rejects synchronous confirmation when authorizationUrl is present', () async {
      final fakeProvider = FakePaystackProvider();
      final service = PaymentService(
        customProviders: {PaymentProviderType.paystack: fakeProvider},
      );
      service.selectProvider(PaymentProviderType.paystack);

      const request = PaymentRequest(
        transactionRef: 'CARD-TEST-001',
        amount: 1000.0,
        customerIdentifier: 'test@payflow.app',
        paymentType: 'wallet_topup',
        description: 'Test Funding',
      );

      final result = await service.processPayment(request);

      // Must be pending and NOT confirmed!
      expect(result.isConfirmed, isFalse);
      expect(result.status, equals(PaymentStatus.pending));
      expect(result.failureReason, contains('https://checkout.paystack.com/test-checkout-url'));
    });

    testWidgets('2. FundWalletSheet initializes Paystack and enters active checkout without pre-crediting wallet', (tester) async {
      bool initializeCalled = false;

      final mockHttp = MockClient((request) async {
        if (request.url.path.contains('/v1/payments/paystack/initialize')) {
          initializeCalled = true;
          return http.Response(
            jsonEncode({
              'status': true,
              'message': 'Authorization URL created',
              'data': {
                'authorization_url': 'https://checkout.paystack.com/test-auth-url',
                'reference': 'CARD-MOCK-REF-101',
              },
            }),
            200,
          );
        }
        if (request.url.path.contains('/v1/payments/paystack/verify')) {
          // Keep ongoing/pending during active checkout
          return http.Response(
            jsonEncode({
              'status': true,
              'data': {'status': 'ongoing'},
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

      // Step 1: Enter ₦1,000 and proceed to review
      final amountField = find.byType(TextField);
      await tester.enterText(amountField, '1000');
      await tester.pump();

      final reviewButton = find.text('Review Top Up');
      await tester.tap(reviewButton);
      await tester.pumpAndSettle();

      // Step 2: Confirm Top Up screen with Pay with Paystack button
      expect(find.text('Confirm Top Up'), findsOneWidget);
      expect(find.text('Pay with Paystack'), findsOneWidget);

      // Tap Pay with Paystack
      await tester.tap(find.text('Pay with Paystack'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Assert initialize endpoint was called
      expect(initializeCalled, isTrue);

      // Assert checkout UI state is rendered
      expect(find.text('Complete Card Payment'), findsOneWidget);
      expect(find.text('Re-open Page'), findsOneWidget);
      expect(find.text('I Have Paid'), findsOneWidget);

      // Balance SAFEGUARD: Balance must NOT be mutated while checkout is ongoing
      final currentBalance = container.read(walletViewModelProvider).mainBalance;
      expect(currentBalance, equals(initialBalance));
    });

    testWidgets('3. Wallet balance is credited ONLY after Paystack verification returns success', (tester) async {
      bool paymentCompletedOnPaystack = false;

      final mockHttp = MockClient((request) async {
        if (request.url.path.contains('/v1/payments/paystack/initialize')) {
          return http.Response(
            jsonEncode({
              'status': true,
              'message': 'Authorization URL created',
              'data': {
                'authorization_url': 'https://checkout.paystack.com/test-auth-url',
                'reference': 'CARD-MOCK-REF-202',
              },
            }),
            200,
          );
        }
        if (request.url.path.contains('/v1/payments/paystack/verify')) {
          if (paymentCompletedOnPaystack) {
            return http.Response(
              jsonEncode({
                'status': true,
                'data': {'status': 'success', 'amount': 100000},
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'status': true,
              'data': {'status': 'ongoing'},
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

      // Enter amount and proceed
      await tester.enterText(find.byType(TextField), '1000');
      await tester.tap(find.text('Review Top Up'));
      await tester.pumpAndSettle();

      // Tap Pay with Paystack
      await tester.tap(find.text('Pay with Paystack'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Complete Card Payment'), findsOneWidget);
      // Balance SAFEGUARD: Not yet credited while ongoing
      expect(container.read(walletViewModelProvider).mainBalance, equals(initialBalance));

      // User completes payment on Paystack's real checkout page
      paymentCompletedOnPaystack = true;

      // User returns and taps "I Have Paid"
      await tester.tap(find.text('I Have Paid'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Top Up Successful! must now be displayed!
      expect(find.text('Top Up Successful!'), findsOneWidget);

      // Wallet balance must now be credited with exactly ₦1,000!
      final updatedBalance = container.read(walletViewModelProvider).mainBalance;
      expect(updatedBalance, equals(initialBalance + 1000.0));

      // Transaction history must record the credit
      final tx = container.read(walletViewModelProvider).transactions.first;
      expect(tx.title, contains('Fund Wallet (Debit Card (Paystack))'));
      expect(tx.amount, equals(1000.0));
      expect(tx.isCredit, isTrue);
    });
  });
}
