import '../models/payment_status.dart';

enum PaymentProviderType {
  mock,
  paystack,
  vtpass,
  flutterwave,
  interswitch,
}

abstract class PaymentProvider {
  PaymentProviderType get providerType;

  /// Initializes a payment session with the provider.
  /// Note: Balance MUST NOT be updated during initialization.
  Future<PaymentResult> initializePayment(PaymentRequest request);

  /// Queries the provider/backend verification endpoint to confirm payment status.
  /// Balance mutation is strictly gated behind `isConfirmed == true`.
  Future<PaymentVerification> verifyPayment(String transactionRef, {String? providerRef});
}
