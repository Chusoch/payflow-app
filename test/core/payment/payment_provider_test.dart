import 'package:flutter_test/flutter_test.dart';
import 'package:payflow/core/payment/models/payment_status.dart';
import 'package:payflow/core/payment/providers/interswitch_payment_provider.dart';
import 'package:payflow/core/payment/providers/mock_payment_provider.dart';
import 'package:payflow/core/payment/providers/payment_provider.dart';
import 'package:payflow/core/payment/services/payment_service.dart';
import 'package:payflow/features/wallet/view_models/wallet_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('PayFlow Stage 7 Payment Infrastructure Tests', () {
    test('1. Provider abstraction interface compliance (Mock vs Interswitch)', () {
      final mock = MockPaymentProvider();
      final isw = InterswitchPaymentProvider();

      expect(mock.providerType, equals(PaymentProviderType.mock));
      expect(isw.providerType, equals(PaymentProviderType.interswitch));
      expect(isw.merchantCode, equals('MX1001'));
    });

    test('2. Mock provider successful payment lifecycle (Initiated -> Verified)', () async {
      final mock = MockPaymentProvider();
      final service = PaymentService(
        customProviders: {PaymentProviderType.mock: mock},
      );

      final req = PaymentRequest(
        transactionRef: 'PF-TEST-001',
        amount: 5000.0,
        customerIdentifier: '@testuser',
        paymentType: 'transfer',
        description: 'Test Transfer',
      );

      final verification = await service.processPayment(req);

      expect(verification.isConfirmed, isTrue);
      expect(verification.status, equals(PaymentStatus.successful));
      expect(verification.transactionRef, equals('PF-TEST-001'));
    });

    test('3. Mock provider initialization failure handling', () async {
      final mockFailed = MockPaymentProvider(shouldFailInitialization: true);
      final service = PaymentService(
        customProviders: {PaymentProviderType.mock: mockFailed},
      );

      final req = PaymentRequest(
        transactionRef: 'PF-TEST-002',
        amount: 2500.0,
        customerIdentifier: '08123456789',
        paymentType: 'airtime',
        description: 'Failed Airtime',
      );

      final verification = await service.processPayment(req);

      expect(verification.isConfirmed, isFalse);
      expect(verification.status, equals(PaymentStatus.failed));
      expect(verification.failureReason, contains('rejected'));
    });

    test('4. Pending payment status simulation', () async {
      final mockPending = MockPaymentProvider(simulatePending: true);
      final service = PaymentService(
        customProviders: {PaymentProviderType.mock: mockPending},
      );

      final req = PaymentRequest(
        transactionRef: 'PF-TEST-003',
        amount: 10000.0,
        customerIdentifier: 'Debit Card',
        paymentType: 'wallet_funding',
        description: 'Pending Funding',
      );

      final verification = await service.processPayment(req);

      expect(verification.isConfirmed, isFalse);
      expect(verification.status, equals(PaymentStatus.pending));
    });

    test('5. Verification failure handling', () async {
      final mockVerifFail = MockPaymentProvider(shouldFailVerification: true);
      final service = PaymentService(
        customProviders: {PaymentProviderType.mock: mockVerifFail},
      );

      final req = PaymentRequest(
        transactionRef: 'PF-TEST-004',
        amount: 1500.0,
        customerIdentifier: 'Meter 0192837465',
        paymentType: 'electricity',
        description: 'Failed Elec',
      );

      final verification = await service.processPayment(req);

      expect(verification.isConfirmed, isFalse);
      expect(verification.status, equals(PaymentStatus.failed));
      expect(verification.failureReason, contains('verification failed'));
    });

    test('6. Idempotency guard prevents duplicate transaction reference processing', () async {
      final mock = MockPaymentProvider();
      final service = PaymentService(
        customProviders: {PaymentProviderType.mock: mock},
      );

      final req = PaymentRequest(
        transactionRef: 'PF-IDEM-001',
        amount: 3000.0,
        customerIdentifier: '@user',
        paymentType: 'transfer',
        description: 'Idempotent Transfer',
      );

      final verif1 = await service.processPayment(req);
      expect(verif1.isConfirmed, isTrue);

      final verif2 = await service.processPayment(req); // Duplicate call
      expect(verif2.isConfirmed, isFalse);
      expect(verif2.failureReason, contains('Idempotency Violation'));
    });

    test('7. Balance Safeguard: Wallet balance NOT updated before verification or on failed verification', () async {
      final walletVM = WalletViewModel();
      final initialBalance = walletVM.state.mainBalance;

      final mockVerifFail = MockPaymentProvider(shouldFailVerification: true);

      final verif = await walletVM.processVerifiedFunding(
        amount: 50000.0,
        method: 'Bank Transfer',
        customProvider: mockVerifFail,
      );

      expect(verif.isConfirmed, isFalse);
      expect(walletVM.state.mainBalance, equals(initialBalance)); // Unchanged!
    });

    test('8. Balance Safeguard: Wallet balance updated ONLY after confirmed verification', () async {
      final walletVM = WalletViewModel();
      final initialBalance = walletVM.state.mainBalance;

      final mockSuccess = MockPaymentProvider();

      final verif = await walletVM.processVerifiedFunding(
        amount: 20000.0,
        method: 'Debit Card',
        customProvider: mockSuccess,
      );

      expect(verif.isConfirmed, isTrue);
      expect(walletVM.state.mainBalance, equals(initialBalance + 20000.0)); // Updated!
      expect(walletVM.state.transactions.first.title, contains('Fund Wallet (Debit Card)'));
    });

    test('9. Interswitch Payment Provider client boundary contract inspection', () async {
      final isw = InterswitchPaymentProvider(merchantCode: 'MX1001');

      final req = PaymentRequest(
        transactionRef: 'PF-ISW-001',
        amount: 15000.0,
        customerIdentifier: 'alex.johnson@payflow.app',
        paymentType: 'wallet_funding',
        description: 'Interswitch Webpay Funding',
      );

      final initResult = await isw.initializePayment(req);
      expect(initResult.status, equals(PaymentStatus.initiated));
      expect(initResult.rawResponse?['merchantCode'], equals('MX1001'));
      expect(initResult.rawResponse?['notice'], contains('Client boundary initialized'));

      final verifResult = await isw.verifyPayment('PF-ISW-001');
      expect(verifResult.isConfirmed, isFalse);
      expect(verifResult.status, equals(PaymentStatus.pending));
    });
  });
}
