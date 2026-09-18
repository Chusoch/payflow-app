enum PaymentStatus {
  initiated,
  pending,
  successful,
  failed,
  cancelled,
}

class PaymentRequest {
  final String transactionRef;
  final double amount;
  final String currency;
  final String customerIdentifier;
  final String customerEmail;
  final String paymentType; // e.g. 'wallet_funding', 'transfer', 'airtime', 'data', 'electricity', 'cable'
  final String description;
  final Map<String, dynamic>? metadata;

  const PaymentRequest({
    required this.transactionRef,
    required this.amount,
    this.currency = 'NGN',
    required this.customerIdentifier,
    this.customerEmail = 'user@payflow.app',
    required this.paymentType,
    required this.description,
    this.metadata,
  });
}

class PaymentResult {
  final String transactionRef;
  final String? providerRef;
  final double amount;
  final PaymentStatus status;
  final DateTime timestamp;
  final String? failureReason;
  final Map<String, dynamic>? rawResponse;

  const PaymentResult({
    required this.transactionRef,
    this.providerRef,
    required this.amount,
    required this.status,
    required this.timestamp,
    this.failureReason,
    this.rawResponse,
  });

  bool get isSuccessful => status == PaymentStatus.successful;
}

class PaymentVerification {
  final String transactionRef;
  final String? providerRef;
  final double amountPaid;
  final PaymentStatus status;
  final bool isConfirmed;
  final DateTime verifiedAt;
  final String? failureReason;

  const PaymentVerification({
    required this.transactionRef,
    this.providerRef,
    required this.amountPaid,
    required this.status,
    required this.isConfirmed,
    required this.verifiedAt,
    this.failureReason,
  });
}
