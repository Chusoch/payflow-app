import '../models/payment_status.dart';
import 'payment_provider.dart';

/// Flutterwave Payment Provider Integration Boundary (SECONDARY / FALLBACK EXTENSION POINT).
/// 
/// Documented extension point for future multi-rail payment fallback.
class FlutterwavePaymentProvider implements PaymentProvider {
  final String publicKey;
  final String environment;

  FlutterwavePaymentProvider({
    String? publicKey,
    this.environment = 'sandbox',
  }) : publicKey = publicKey ?? const String.fromEnvironment('FLUTTERWAVE_PUBLIC_KEY', defaultValue: '');

  @override
  PaymentProviderType get providerType => PaymentProviderType.flutterwave;

  @override
  Future<PaymentResult> initializePayment(PaymentRequest request) async {
    final providerRef = 'FLW-${DateTime.now().millisecondsSinceEpoch}';
    return PaymentResult(
      transactionRef: request.transactionRef,
      providerRef: providerRef,
      amount: request.amount,
      status: PaymentStatus.initiated,
      timestamp: DateTime.now(),
      rawResponse: {
        'notice': 'Flutterwave extension point initialized. Active processing is handled by Paystack/VTPass.',
      },
    );
  }

  @override
  Future<PaymentVerification> verifyPayment(String transactionRef, {String? providerRef}) async {
    return PaymentVerification(
      transactionRef: transactionRef,
      providerRef: providerRef ?? 'FLW-SANDBOX',
      amountPaid: 0.0,
      status: PaymentStatus.pending,
      isConfirmed: false,
      verifiedAt: DateTime.now(),
      failureReason: 'Flutterwave backend verification endpoint not configured',
    );
  }
}
