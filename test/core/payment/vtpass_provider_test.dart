import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:payflow/core/payment/models/payment_status.dart';
import 'package:payflow/core/payment/providers/payment_provider.dart';
import 'package:payflow/core/payment/providers/vtpass_payment_provider.dart';

void main() {
  group('VTPassPaymentProvider Unit Tests (Mocked HTTP)', () {
    test('providerType returns PaymentProviderType.vtpass', () {
      final provider = VTPassPaymentProvider();
      expect(provider.providerType, equals(PaymentProviderType.vtpass));
    });

    test('initializePayment returns client boundary initiated result when backend URL is null', () async {
      final provider = VTPassPaymentProvider();
      final request = PaymentRequest(
        transactionRef: 'PF-VTP-TEST-001',
        amount: 2000.0,
        customerIdentifier: '08123456789',
        paymentType: 'airtime_mtn',
        description: 'MTN Airtime Purchase',
      );

      final result = await provider.initializePayment(request);
      expect(result.status, equals(PaymentStatus.initiated));
      expect(result.transactionRef, equals('PF-VTP-TEST-001'));
      expect(result.rawResponse?['notice'], contains('VTPass sandbox boundary initialized'));
    });

    test('initializePayment delegates to backend API and returns pending result when HTTP 200 code 000', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), equals('https://api.payflow.app/v1/payments/vtpass/pay'));
        return http.Response(
          jsonEncode({
            'code': '000',
            'content': {
              'transactions': {
                'status': 'initiated',
                'product_name': 'MTN Airtime',
                'requestId': 'VTP-REQ-1029',
              }
            },
            'response_description': 'TRANSACTION SUCCESSFUL',
          }),
          200,
        );
      });

      final provider = VTPassPaymentProvider(
        backendApiBaseUrl: 'https://api.payflow.app',
        httpClient: mockClient,
      );

      final request = PaymentRequest(
        transactionRef: 'PF-VTP-TEST-002',
        amount: 1500.0,
        customerIdentifier: '08123456789',
        paymentType: 'airtime_mtn',
        description: 'MTN Airtime Purchase Backend',
      );

      final result = await provider.initializePayment(request);
      expect(result.status, equals(PaymentStatus.pending));
      expect(result.providerRef, startsWith('VTP-'));
    });

    test('verifyPayment handles successful requery response from backend API', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), equals('https://api.payflow.app/v1/payments/vtpass/requery'));
        return http.Response(
          jsonEncode({
            'code': '000',
            'content': {
              'transactions': {
                'status': 'delivered',
                'amount': 1500,
              }
            },
            'amount': 1500,
            'response_description': 'TRANSACTION SUCCESSFUL',
          }),
          200,
        );
      });

      final provider = VTPassPaymentProvider(
        backendApiBaseUrl: 'https://api.payflow.app',
        httpClient: mockClient,
      );

      final verification = await provider.verifyPayment('PF-VTP-TEST-002', providerRef: 'VTP-REQ-1029');
      expect(verification.isConfirmed, isTrue);
      expect(verification.status, equals(PaymentStatus.successful));
      expect(verification.amountPaid, equals(1500.0));
    });

    test('verifyPayment handles failed requery response cleanly', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'code': '016',
            'response_description': 'TRANSACTION FAILED - TRANSACTION DOES NOT EXIST',
          }),
          200,
        );
      });

      final provider = VTPassPaymentProvider(
        backendApiBaseUrl: 'https://api.payflow.app',
        httpClient: mockClient,
      );

      final verification = await provider.verifyPayment('PF-VTP-TEST-003', providerRef: 'VTP-INVALID');
      expect(verification.isConfirmed, isFalse);
      expect(verification.status, equals(PaymentStatus.failed));
      expect(verification.failureReason, equals('TRANSACTION FAILED - TRANSACTION DOES NOT EXIST'));
    });

    test('verifyPayment preserves success if payment already succeeded during initialization even if requery fails', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/pay')) {
          return http.Response(
            jsonEncode({
              'code': '000',
              'status': 'success',
              'response_description': 'TRANSACTION SUCCESSFUL',
            }),
            200,
          );
        }
        // Requery endpoint fails with 401 / 500
        return http.Response(
          jsonEncode({
            'code': '087',
            'message': 'INVALID CREDENTIALS',
          }),
          401,
        );
      });

      final provider = VTPassPaymentProvider(
        backendApiBaseUrl: 'https://api.payflow.app',
        httpClient: mockClient,
      );

      final request = PaymentRequest(
        transactionRef: 'PF-VTP-TEST-004',
        amount: 2500.0,
        customerIdentifier: '08146357043',
        paymentType: 'airtime',
        description: 'MTN Airtime 2500',
      );

      final initResult = await provider.initializePayment(request);
      expect(initResult.status, equals(PaymentStatus.pending));

      final verification = await provider.verifyPayment(
        request.transactionRef,
        providerRef: initResult.providerRef,
      );

      expect(verification.isConfirmed, isTrue);
      expect(verification.status, equals(PaymentStatus.successful));
      expect(verification.amountPaid, equals(2500.0));
      expect(verification.failureReason, isNull);
    });
  });
}
