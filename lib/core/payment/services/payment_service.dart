import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/env.dart';
import '../models/payment_status.dart';
import '../providers/flutterwave_payment_provider.dart';
import '../providers/interswitch_payment_provider.dart';
import '../providers/mock_payment_provider.dart';
import '../providers/payment_provider.dart';
import '../providers/paystack_payment_provider.dart';
import '../providers/vtpass_payment_provider.dart';

class PaymentServiceState {
  final PaymentProviderType activeProviderType;
  final bool isProcessing;
  final String? lastProcessedReference;
  final PaymentStatus? lastStatus;

  PaymentServiceState({
    PaymentProviderType? activeProviderType,
    this.isProcessing = false,
    this.lastProcessedReference,
    this.lastStatus,
  }) : activeProviderType = activeProviderType ??
            (Env.isMockMode
                ? PaymentProviderType.mock
                : PaymentProviderType.paystack);

  PaymentServiceState copyWith({
    PaymentProviderType? activeProviderType,
    bool? isProcessing,
    String? lastProcessedReference,
    PaymentStatus? lastStatus,
  }) {
    return PaymentServiceState(
      activeProviderType: activeProviderType ?? this.activeProviderType,
      isProcessing: isProcessing ?? this.isProcessing,
      lastProcessedReference: lastProcessedReference ?? this.lastProcessedReference,
      lastStatus: lastStatus ?? this.lastStatus,
    );
  }
}

class PaymentService extends StateNotifier<PaymentServiceState> {
  final Map<PaymentProviderType, PaymentProvider> _providers;
  final Set<String> _processedReferences = {};

  PaymentService({
    Map<PaymentProviderType, PaymentProvider>? customProviders,
    PaymentProviderType? initialProviderType,
  })  : _providers = customProviders ??
            {
              PaymentProviderType.mock: MockPaymentProvider(),
              PaymentProviderType.paystack: PaystackPaymentProvider(backendApiBaseUrl: Env.backendApiBaseUrl),
              PaymentProviderType.vtpass: VTPassPaymentProvider(backendApiBaseUrl: Env.backendApiBaseUrl),
              PaymentProviderType.flutterwave: FlutterwavePaymentProvider(),
              PaymentProviderType.interswitch: InterswitchPaymentProvider(),
            },
        super(PaymentServiceState(
          activeProviderType: initialProviderType ??
              (Env.isMockMode
                  ? PaymentProviderType.mock
                  : PaymentProviderType.paystack),
        ));

  PaymentProvider get currentProvider =>
      _providers[state.activeProviderType] ?? MockPaymentProvider();

  void selectProvider(PaymentProviderType type) {
    state = state.copyWith(activeProviderType: type);
  }

  /// Exposes provider initialization directly (useful for interactive checkouts like Paystack)
  Future<PaymentResult> initializePayment(PaymentRequest request) async {
    return currentProvider.initializePayment(request);
  }

  /// Exposes provider verification directly
  Future<PaymentVerification> verifyPayment(String transactionRef, {String? providerRef}) async {
    return currentProvider.verifyPayment(transactionRef, providerRef: providerRef);
  }

  /// Processes payment through strict required lifecycle:
  /// Initiated → Pending → Provider Verification → Confirmed Success / Failed
  /// 
  /// Enforces IDEMPOTENCY: Rejects duplicate processing for the same reference.
  /// Enforces BALANCE SAFEGUARD: Wallet mutation occurs ONLY after `isConfirmed == true`.
  Future<PaymentVerification> processPayment(PaymentRequest request) async {
    // 1. Idempotency Safeguard Check
    if (_processedReferences.contains(request.transactionRef)) {
      return PaymentVerification(
        transactionRef: request.transactionRef,
        amountPaid: 0.0,
        status: PaymentStatus.failed,
        isConfirmed: false,
        verifiedAt: DateTime.now(),
        failureReason: 'Idempotency Violation: Transaction reference ${request.transactionRef} already processed',
      );
    }

    state = state.copyWith(isProcessing: true);

    try {
      // 2. Step 1: Initiated
      final initResult = await currentProvider.initializePayment(request);

      if (initResult.status == PaymentStatus.failed) {
        state = state.copyWith(
          isProcessing: false,
          lastProcessedReference: request.transactionRef,
          lastStatus: PaymentStatus.failed,
        );
        return PaymentVerification(
          transactionRef: request.transactionRef,
          providerRef: initResult.providerRef,
          amountPaid: 0.0,
          status: PaymentStatus.failed,
          isConfirmed: false,
          verifiedAt: DateTime.now(),
          failureReason: initResult.failureReason ?? 'Payment initialization failed',
        );
      }

      // If interactive checkout redirect is required (e.g. Paystack authorization_url),
      // the payment CANNOT be confirmed synchronously without user completing authorization!
      final authUrl = initResult.rawResponse?['authorizationUrl'] as String?;
      if (authUrl != null && authUrl.isNotEmpty) {
        state = state.copyWith(
          isProcessing: false,
          lastProcessedReference: request.transactionRef,
          lastStatus: PaymentStatus.pending,
        );
        return PaymentVerification(
          transactionRef: request.transactionRef,
          providerRef: initResult.providerRef,
          amountPaid: 0.0,
          status: PaymentStatus.pending,
          isConfirmed: false,
          verifiedAt: DateTime.now(),
          failureReason: 'Payment requires user card authorization at: $authUrl',
        );
      }

      // 3. Step 2 & 3: Pending & Provider Verification
      final verification = await currentProvider.verifyPayment(
        request.transactionRef,
        providerRef: initResult.providerRef,
      );

      // 4. Step 4: Record Idempotency & Final Status
      if (verification.isConfirmed) {
        _processedReferences.add(request.transactionRef);
      }

      state = state.copyWith(
        isProcessing: false,
        lastProcessedReference: request.transactionRef,
        lastStatus: verification.status,
      );

      return verification;
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        lastProcessedReference: request.transactionRef,
        lastStatus: PaymentStatus.failed,
      );
      return PaymentVerification(
        transactionRef: request.transactionRef,
        amountPaid: 0.0,
        status: PaymentStatus.failed,
        isConfirmed: false,
        verifiedAt: DateTime.now(),
        failureReason: 'Unexpected provider processing error: ${e.toString()}',
      );
    }
  }

  bool isReferenceProcessed(String refCode) {
    return _processedReferences.contains(refCode);
  }
}

final paymentServiceProvider =
    StateNotifierProvider<PaymentService, PaymentServiceState>((ref) {
  return PaymentService();
});
