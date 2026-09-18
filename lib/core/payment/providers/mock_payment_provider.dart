import '../models/payment_status.dart';
import 'payment_provider.dart';

class MockPaymentProvider implements PaymentProvider {
  final bool shouldFailInitialization;
  final bool shouldFailVerification;
  final bool simulatePending;
  final Duration delay;

  final Map<String, PaymentResult> _initializedPayments = {};

  MockPaymentProvider({
    this.shouldFailInitialization = false,
    this.shouldFailVerification = false,
    this.simulatePending = false,
    this.delay = Duration.zero,
  });

  @override
  PaymentProviderType get providerType => PaymentProviderType.mock;

  @override
  Future<PaymentResult> initializePayment(PaymentRequest request) async {
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }

    if (shouldFailInitialization) {
      final failedResult = PaymentResult(
        transactionRef: request.transactionRef,
        amount: request.amount,
        status: PaymentStatus.failed,
        timestamp: DateTime.now(),
        failureReason: 'Provider initialization rejected: Invalid request parameters',
      );
      _initializedPayments[request.transactionRef] = failedResult;
      return failedResult;
    }

    final status = simulatePending ? PaymentStatus.pending : PaymentStatus.initiated;
    final providerRef = 'ISW-MOCK-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

    final result = PaymentResult(
      transactionRef: request.transactionRef,
      providerRef: providerRef,
      amount: request.amount,
      status: status,
      timestamp: DateTime.now(),
      rawResponse: {
        'responseCode': status == PaymentStatus.pending ? '99' : '00',
        'merchantCode': 'MX1001_MOCK',
        'providerReference': providerRef,
      },
    );

    _initializedPayments[request.transactionRef] = result;
    return result;
  }

  @override
  Future<PaymentVerification> verifyPayment(String transactionRef, {String? providerRef}) async {
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }

    final initRecord = _initializedPayments[transactionRef];

    if (shouldFailVerification || initRecord?.status == PaymentStatus.failed) {
      return PaymentVerification(
        transactionRef: transactionRef,
        providerRef: providerRef ?? initRecord?.providerRef,
        amountPaid: initRecord?.amount ?? 0.0,
        status: PaymentStatus.failed,
        isConfirmed: false,
        verifiedAt: DateTime.now(),
        failureReason: 'Payment verification failed: Transaction not found or rejected by provider',
      );
    }

    if (simulatePending || initRecord?.status == PaymentStatus.pending) {
      return PaymentVerification(
        transactionRef: transactionRef,
        providerRef: providerRef ?? initRecord?.providerRef,
        amountPaid: initRecord?.amount ?? 0.0,
        status: PaymentStatus.pending,
        isConfirmed: false,
        verifiedAt: DateTime.now(),
        failureReason: 'Payment is pending bank authorization',
      );
    }

    return PaymentVerification(
      transactionRef: transactionRef,
      providerRef: providerRef ?? initRecord?.providerRef ?? 'ISW-MOCK-VERIFIED',
      amountPaid: initRecord?.amount ?? 0.0,
      status: PaymentStatus.successful,
      isConfirmed: true,
      verifiedAt: DateTime.now(),
    );
  }
}
