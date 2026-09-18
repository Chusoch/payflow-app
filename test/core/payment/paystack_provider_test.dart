import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:payflow/core/payment/models/payment_status.dart';
import 'package:payflow/core/payment/providers/payment_provider.dart';
import 'package:payflow/core/payment/providers/paystack_payment_provider.dart';

void main() {
  group('PaystackPaymentProvider Unit Tests (Mocked HTTP)', () {
    test('providerType returns PaymentProviderType.paystack', () {
      final provider = PaystackPaymentProvider();
      expect(provider.providerType, equals(PaymentProviderType.paystack));
    });

    test('initializePayment returns client boundary initiated result when backend URL is null', () async {
      final provider = PaystackPaymentProvider();
      final request = PaymentRequest(
        transactionRef: 'PF-PST-TEST-001',
        amount: 5000.0,
        customerIdentifier: 'alex.j@payflow.app',
        paymentType: 'wallet_topup',
        description: 'Test Wallet Topup',
      );

      final result = await provider.initializePayment(request);
      expect(result.status, equals(PaymentStatus.initiated));
      expect(result.transactionRef, equals('PF-PST-TEST-001'));
      expect(result.rawResponse?['notice'], contains('Paystack client boundary initialized'));
    });

    test('initializePayment delegates to backend API and returns pending result when HTTP 200', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), equals('https://api.payflow.app/v1/payments/paystack/initialize'));
        return http.Response(
          jsonEncode({
            'status': true,
            'data': {
              'authorization_url': 'https://checkout.paystack.com/access_code_123',
              'access_code': 'access_code_123',
              'reference': 'PST-REF-8899',
            }
          }),
          200,
        );
      });

      final provider = PaystackPaymentProvider(
        backendApiBaseUrl: 'https://api.payflow.app',
        httpClient: mockClient,
      );

      final request = PaymentRequest(
        transactionRef: 'PF-PST-TEST-002',
        amount: 10000.0,
        customerIdentifier: 'alex.j@payflow.app',
        paymentType: 'wallet_topup',
        description: 'Test Wallet Topup Backend',
      );

      final result = await provider.initializePayment(request);
      expect(result.status, equals(PaymentStatus.pending));
      expect(result.providerRef, equals('PST-REF-8899'));
    });

    test('verifyPayment parses successful verification response from backend API', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), equals('https://api.payflow.app/v1/payments/paystack/verify/PST-REF-8899'));
        return http.Response(
          jsonEncode({
            'status': true,
            'data': {
              'status': 'success',
              'reference': 'PST-REF-8899',
              'amount': 1000000, // 10,000 NGN in kobo
              'gateway_response': 'Successful',
            }
          }),
          200,
        );
      });

      final provider = PaystackPaymentProvider(
        backendApiBaseUrl: 'https://api.payflow.app',
        httpClient: mockClient,
      );

      final verification = await provider.verifyPayment('PF-PST-TEST-002', providerRef: 'PST-REF-8899');
      expect(verification.isConfirmed, isTrue);
      expect(verification.status, equals(PaymentStatus.successful));
      expect(verification.amountPaid, equals(10000.0));
    });

    test('verifyPayment handles failed verification response cleanly', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status': true,
            'data': {
              'status': 'failed',
              'reference': 'PST-REF-FAIL',
              'amount': 0,
              'gateway_response': 'Declined by bank',
            }
          }),
          200,
        );
      });

      final provider = PaystackPaymentProvider(
        backendApiBaseUrl: 'https://api.payflow.app',
        httpClient: mockClient,
      );

      final verification = await provider.verifyPayment('PF-PST-TEST-003', providerRef: 'PST-REF-FAIL');
      expect(verification.isConfirmed, isFalse);
      expect(verification.status, equals(PaymentStatus.failed));
      expect(verification.failureReason, equals('Declined by bank'));
    });
  });
}
