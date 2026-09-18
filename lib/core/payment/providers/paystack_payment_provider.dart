import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../network/api_client.dart';
import '../models/payment_status.dart';
import 'payment_provider.dart';

/// Paystack Payment Provider Integration Boundary for Wallet Funding & Transfers.
/// 
/// SECURITY ARCHITECTURE NOTICE:
/// Secret keys (`sk_live_...` or `sk_test_...`) and webhook signing secrets MUST NEVER be
/// embedded in Flutter client source code, `dart-define` environment flags, or binary assets,
/// as client binaries are vulnerable to APK/IPA reverse-engineering key extraction.
/// 
/// Direct un-proxied client-side network calls requiring secret keys are strictly blocked in client builds.
/// All live secret-key payment operations (initialize, verify) MUST be proxied through a secure PayFlow backend.
/// This class is structurally complete and exercised via unit tests with an injected mocked `http.Client`.
/// `MockPaymentProvider` remains the active default provider for the running client application.
class PaystackPaymentProvider implements PaymentProvider {
  final String publicKey;
  final String environment; // 'sandbox' or 'production'
  final String? backendApiBaseUrl;
  final ApiClient _apiClient;

  PaystackPaymentProvider({
    String? publicKey,
    this.environment = 'sandbox',
    this.backendApiBaseUrl,
    http.Client? httpClient,
    ApiClient? apiClient,
  })  : publicKey = publicKey ??
            const String.fromEnvironment('PAYSTACK_PUBLIC_KEY', defaultValue: ''),
        _apiClient = apiClient ??
            ApiClient(
              baseUrl: backendApiBaseUrl ?? '',
              httpClient: httpClient,
            );

  @override
  PaymentProviderType get providerType => PaymentProviderType.paystack;

  @override
  Future<PaymentResult> initializePayment(PaymentRequest request) async {
    final providerRef = 'PST-${DateTime.now().millisecondsSinceEpoch}';

    // If backend endpoint is configured, delegate request
    if (backendApiBaseUrl != null && backendApiBaseUrl!.isNotEmpty) {
      try {
        final response = await _apiClient.post(
          '/v1/payments/paystack/initialize',
          body: {
            'reference': request.transactionRef,
            'amount_in_kobo': (request.amount * 100).toInt(),
            'email': request.customerIdentifier.contains('@')
                ? request.customerIdentifier
                : '${request.customerIdentifier.replaceAll('@', '')}@payflow.app',
            'payment_type': request.paymentType,
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final authorizationUrl = data['data']?['authorization_url'] as String?;
          final ref = data['data']?['reference'] as String? ?? providerRef;

          return PaymentResult(
            transactionRef: request.transactionRef,
            providerRef: ref,
            amount: request.amount,
            status: PaymentStatus.pending,
            timestamp: DateTime.now(),
            rawResponse: {
              'authorizationUrl': authorizationUrl,
              'status': 'success',
            },
          );
        } else {
          String errorMsg = 'Paystack initialization failed (Status ${response.statusCode})';
          try {
            final data = jsonDecode(response.body);
            errorMsg = data['message'] ?? data['error'] ?? errorMsg;
          } catch (_) {}

          return PaymentResult(
            transactionRef: request.transactionRef,
            providerRef: providerRef,
            amount: request.amount,
            status: PaymentStatus.failed,
            timestamp: DateTime.now(),
            failureReason: errorMsg,
          );
        }
      } catch (e) {
        return PaymentResult(
          transactionRef: request.transactionRef,
          providerRef: providerRef,
          amount: request.amount,
          status: PaymentStatus.failed,
          timestamp: DateTime.now(),
          failureReason: 'Paystack initialization network error: ${e.toString()}',
        );
      }
    }

    // Client boundary initialization (sandbox mode without active backend URL)
    return PaymentResult(
      transactionRef: request.transactionRef,
      providerRef: providerRef,
      amount: request.amount,
      status: PaymentStatus.initiated,
      timestamp: DateTime.now(),
      rawResponse: {
        'publicKey': publicKey.isNotEmpty ? '${publicKey.substring(0, 7)}...' : 'CONFIGURED_IN_ENV',
        'environment': environment,
        'notice': 'Paystack client boundary initialized. Requires backend server for live transaction signing.',
      },
    );
  }

  @override
  Future<PaymentVerification> verifyPayment(String transactionRef, {String? providerRef}) async {
    final targetRef = providerRef ?? transactionRef;

    if (backendApiBaseUrl != null && backendApiBaseUrl!.isNotEmpty) {
      try {
        final response = await _apiClient.get(
          '/v1/payments/paystack/verify/$targetRef',
        );

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          final statusStr = json['data']?['status'] as String?;
          final amountKobo = (json['data']?['amount'] as num?)?.toDouble() ?? 0.0;

          final isSuccess = statusStr == 'success';
          return PaymentVerification(
            transactionRef: transactionRef,
            providerRef: targetRef,
            amountPaid: amountKobo / 100.0,
            status: isSuccess ? PaymentStatus.successful : PaymentStatus.failed,
            isConfirmed: isSuccess,
            verifiedAt: DateTime.now(),
            failureReason: isSuccess ? null : json['data']?['gateway_response'] as String? ?? 'Verification failed',
          );
        } else {
          String errorMsg = 'Paystack verification failed (Status ${response.statusCode})';
          try {
            final data = jsonDecode(response.body);
            errorMsg = data['message'] ?? data['error'] ?? errorMsg;
          } catch (_) {}
          return PaymentVerification(
            transactionRef: transactionRef,
            providerRef: targetRef,
            amountPaid: 0.0,
            status: PaymentStatus.failed,
            isConfirmed: false,
            verifiedAt: DateTime.now(),
            failureReason: errorMsg,
          );
        }
      } catch (e) {
        return PaymentVerification(
          transactionRef: transactionRef,
          providerRef: targetRef,
          amountPaid: 0.0,
          status: PaymentStatus.failed,
          isConfirmed: false,
          verifiedAt: DateTime.now(),
          failureReason: 'Paystack verification exception: ${e.toString()}',
        );
      }
    }

    // Default boundary state when backend API is not configured
    return PaymentVerification(
      transactionRef: transactionRef,
      providerRef: targetRef,
      amountPaid: 0.0,
      status: PaymentStatus.pending,
      isConfirmed: false,
      verifiedAt: DateTime.now(),
      failureReason: 'Paystack production backend verification endpoint not configured',
    );
  }
}
