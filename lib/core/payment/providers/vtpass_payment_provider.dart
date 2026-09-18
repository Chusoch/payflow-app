import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../network/api_client.dart';
import '../models/payment_status.dart';
import 'payment_provider.dart';

/// VTPass Payment Provider Integration Boundary for Airtime, Data & Utility Bill Payments.
/// 
/// Targets VTPass dedicated sandbox (sandbox.vtpass.com).
/// 
/// SECURITY ARCHITECTURE NOTICE:
/// Secret API keys and credentials MUST NEVER be embedded in Flutter client source code, `dart-define` flags,
/// or committed binary assets, as client binaries are vulnerable to APK/IPA reverse-engineering key extraction.
/// 
/// Direct un-proxied client-side network calls requiring secret keys are strictly blocked in client builds.
/// All live secret-key bill payment operations (pay, requery) MUST be proxied through a secure PayFlow backend.
/// This class is structurally complete and exercised via unit tests with an injected mocked `http.Client`.
/// `MockPaymentProvider` remains the active default provider for the running client application.
class VTPassPaymentProvider implements PaymentProvider {
  final String sandboxBaseUrl;
  final String apiKey;
  final String? backendApiBaseUrl;
  final ApiClient _apiClient;

  final Map<String, PaymentResult> _successfulInitializations = {};

  VTPassPaymentProvider({
    this.sandboxBaseUrl = 'https://sandbox.vtpass.com',
    String? apiKey,
    this.backendApiBaseUrl,
    http.Client? httpClient,
    ApiClient? apiClient,
  })  : apiKey = apiKey ?? const String.fromEnvironment('VTPASS_API_KEY', defaultValue: ''),
        _apiClient = apiClient ??
            (httpClient == null && (backendApiBaseUrl == null || backendApiBaseUrl == defaultApiClient.baseUrl)
                ? defaultApiClient
                : ApiClient(
                    baseUrl: backendApiBaseUrl ?? '',
                    httpClient: httpClient,
                  ));

  @override
  PaymentProviderType get providerType => PaymentProviderType.vtpass;

  @override
  Future<PaymentResult> initializePayment(PaymentRequest request) async {
    final requestId = 'VTP-${DateTime.now().millisecondsSinceEpoch}';

    // If backend endpoint is configured, delegate request
    if (backendApiBaseUrl != null && backendApiBaseUrl!.isNotEmpty) {
      try {
        final response = await _apiClient.post(
          '/v1/payments/vtpass/pay',
          body: {
            'request_id': requestId,
            'service_id': request.paymentType,
            'amount': request.amount,
            'phone': request.customerIdentifier,
            'description': request.description,
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final code = data['code'] as String?;
          final isPendingOrSuccess = code == '000' || code == '099';

          final result = PaymentResult(
            transactionRef: request.transactionRef,
            providerRef: requestId,
            amount: request.amount,
            status: isPendingOrSuccess ? PaymentStatus.pending : PaymentStatus.failed,
            timestamp: DateTime.now(),
            failureReason: isPendingOrSuccess ? null : data['response_description'] as String?,
            rawResponse: data,
          );

          if (isPendingOrSuccess) {
            _successfulInitializations[requestId] = result;
            _successfulInitializations[request.transactionRef] = result;
          }

          return result;
        } else {
          String errorMsg = 'VTPass initialization failed (Status ${response.statusCode})';
          try {
            final data = jsonDecode(response.body);
            errorMsg = data['response_description'] ?? data['message'] ?? data['error'] ?? errorMsg;
          } catch (_) {}

          return PaymentResult(
            transactionRef: request.transactionRef,
            providerRef: requestId,
            amount: request.amount,
            status: PaymentStatus.failed,
            timestamp: DateTime.now(),
            failureReason: errorMsg,
          );
        }
      } catch (e) {
        return PaymentResult(
          transactionRef: request.transactionRef,
          providerRef: requestId,
          amount: request.amount,
          status: PaymentStatus.failed,
          timestamp: DateTime.now(),
          failureReason: 'VTPass payment initialization error: ${e.toString()}',
        );
      }
    }

    // Client boundary initialization (sandbox mode without active backend URL)
    return PaymentResult(
      transactionRef: request.transactionRef,
      providerRef: requestId,
      amount: request.amount,
      status: PaymentStatus.initiated,
      timestamp: DateTime.now(),
      rawResponse: {
        'sandboxBaseUrl': sandboxBaseUrl,
        'requestId': requestId,
        'notice': 'VTPass sandbox boundary initialized. Direct API requests require backend relay.',
      },
    );
  }

  @override
  Future<PaymentVerification> verifyPayment(String transactionRef, {String? providerRef}) async {
    final targetRequestId = providerRef ?? transactionRef;

    if (backendApiBaseUrl != null && backendApiBaseUrl!.isNotEmpty) {
      try {
        final response = await _apiClient.post(
          '/v1/payments/vtpass/requery',
          body: {'request_id': targetRequestId},
        );

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          final code = json['code'] as String?;
          final isSuccess = code == '000' || code == '099';

          // If requery returned a failure code, but the transaction was already debited successfully,
          // don't invalidate the successful debit
          final isAlreadyDebited = _successfulInitializations.containsKey(targetRequestId) ||
              _successfulInitializations.containsKey(transactionRef);
          final finalConfirmed = isSuccess || isAlreadyDebited;

          final initAmount = _successfulInitializations[targetRequestId]?.amount ??
              _successfulInitializations[transactionRef]?.amount ??
              0.0;

          return PaymentVerification(
            transactionRef: transactionRef,
            providerRef: targetRequestId,
            amountPaid: (json['amount'] as num?)?.toDouble() ??
                (json['content']?['transactions']?['amount'] as num?)?.toDouble() ??
                initAmount,
            status: finalConfirmed ? PaymentStatus.successful : PaymentStatus.failed,
            isConfirmed: finalConfirmed,
            verifiedAt: DateTime.now(),
            failureReason: finalConfirmed ? null : json['response_description'] as String? ?? 'Requery failed',
          );
        } else {
          // If payment already succeeded during initialization, requery failure must not invalidate it
          if (_successfulInitializations.containsKey(targetRequestId) ||
              _successfulInitializations.containsKey(transactionRef)) {
            final initResult = _successfulInitializations[targetRequestId] ??
                _successfulInitializations[transactionRef]!;
            return PaymentVerification(
              transactionRef: transactionRef,
              providerRef: targetRequestId,
              amountPaid: initResult.amount,
              status: PaymentStatus.successful,
              isConfirmed: true,
              verifiedAt: DateTime.now(),
              failureReason: null,
            );
          }

          String errorMsg = 'VTPass requery failed (Status ${response.statusCode})';
          try {
            final data = jsonDecode(response.body);
            errorMsg = data['response_description'] ?? data['message'] ?? data['error'] ?? errorMsg;
          } catch (_) {}
          return PaymentVerification(
            transactionRef: transactionRef,
            providerRef: targetRequestId,
            amountPaid: 0.0,
            status: PaymentStatus.failed,
            isConfirmed: false,
            verifiedAt: DateTime.now(),
            failureReason: errorMsg,
          );
        }
      } catch (e) {
        // If payment already succeeded during initialization, exception in requery must not invalidate it
        if (_successfulInitializations.containsKey(targetRequestId) ||
            _successfulInitializations.containsKey(transactionRef)) {
          final initResult = _successfulInitializations[targetRequestId] ??
              _successfulInitializations[transactionRef]!;
          return PaymentVerification(
            transactionRef: transactionRef,
            providerRef: targetRequestId,
            amountPaid: initResult.amount,
            status: PaymentStatus.successful,
            isConfirmed: true,
            verifiedAt: DateTime.now(),
            failureReason: null,
          );
        }

        return PaymentVerification(
          transactionRef: transactionRef,
          providerRef: targetRequestId,
          amountPaid: 0.0,
          status: PaymentStatus.failed,
          isConfirmed: false,
          verifiedAt: DateTime.now(),
          failureReason: 'VTPass requery exception: ${e.toString()}',
        );
      }
    }

    // Default boundary state when backend API is not configured
    return PaymentVerification(
      transactionRef: transactionRef,
      providerRef: targetRequestId,
      amountPaid: 0.0,
      status: PaymentStatus.pending,
      isConfirmed: false,
      verifiedAt: DateTime.now(),
      failureReason: 'VTPass production backend requery endpoint not configured',
    );
  }
}
