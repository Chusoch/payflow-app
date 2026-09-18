import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_dimensions.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/payflow_button.dart';
import '../../../core/widgets/payflow_card.dart';
import '../../../core/widgets/payflow_text_field.dart';
import '../../auth/view_models/auth_view_model.dart';
import '../../profile/view_models/profile_view_model.dart';
import '../view_models/wallet_view_model.dart';

class FundWalletSheet extends ConsumerStatefulWidget {
  const FundWalletSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FundWalletSheet(),
    );
  }

  @override
  ConsumerState<FundWalletSheet> createState() => _FundWalletSheetState();
}

class _FundWalletSheetState extends ConsumerState<FundWalletSheet> {
  int _step = 1; // 1: Method & Amount, 2: Review / DVA Display, 3: Success
  String _selectedMethod = 'Debit Card';
  final _amountController = TextEditingController();
  String? _errorText;
  double _fundedAmount = 0;

  // Dedicated Virtual Account (DVA) State
  bool _isLoadingDva = false;
  String? _dvaError;
  String? _dvaAccountNumber;
  String? _dvaBankName;
  String? _dvaAccountName;
  String? _dvaReference;
  bool _isPolling = false;
  bool _pollingTimedOut = false;
  Timer? _pollingTimer;
  int _pollAttempts = 0;
  static const int _maxPollAttempts = 30; // 30 attempts * 3s = 90s bounded timeout

  // Debit Card / Paystack Checkout State
  bool _isInitializingCard = false;
  String? _cardError;
  String? _cardReference;
  String? _cardAuthorizationUrl;

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _amountController.dispose();
    super.dispose();
  }

  void _onQuickAmountSelected(double amount) {
    setState(() {
      _amountController.text = amount.toStringAsFixed(0);
      _errorText = null;
    });
  }

  Future<void> _proceedToReview() async {
    final text = _amountController.text.trim();
    final amount = double.tryParse(text);
    if (amount == null || amount <= 0) {
      setState(() {
        _errorText = 'Please enter a valid amount greater than ₦0';
      });
      return;
    }

    setState(() {
      _errorText = null;
      _fundedAmount = amount;
      _step = 2;
    });

    if (_selectedMethod == 'Bank Transfer') {
      await _fetchDedicatedAccount();
    }
  }

  Future<void> _fetchDedicatedAccount() async {
    setState(() {
      _isLoadingDva = true;
      _dvaError = null;
      _pollingTimedOut = false;
    });

    final txRef = 'DVA-${DateTime.now().millisecondsSinceEpoch}';
    _dvaReference = txRef;

    try {
      final response = await defaultApiClient.post(
        '/v1/payments/paystack/dedicated-account',
        body: {'amount_in_kobo': (_fundedAmount * 100).toInt()},
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final rawData = json['data'];
        final Map<String, dynamic> data = rawData is Map<String, dynamic> ? rawData : {};
        final acctNum = data['account_number'] as String?;
        if (acctNum != null && acctNum.isNotEmpty) {
          setState(() {
            _dvaAccountNumber = acctNum;
            _dvaBankName = (data['bank'] is Map ? data['bank']['name'] : null) as String? ?? 'Wema Bank';
            _dvaAccountName = data['account_name'] as String? ?? 'PayFlow / Dedicated Account';
            _isLoadingDva = false;
            _dvaError = null;
          });

          _startBoundedPolling(txRef);
          return;
        }
      }

      String errorMsg = 'Failed to generate dedicated virtual account';
      try {
        final json = jsonDecode(response.body);
        errorMsg = json['message'] ?? json['error'] ?? errorMsg;
      } catch (_) {}

      setState(() {
        _dvaAccountNumber = null;
        _dvaBankName = null;
        _dvaAccountName = null;
        _isLoadingDva = false;
        _dvaError = errorMsg;
      });
    } catch (_) {
      setState(() {
        _dvaAccountNumber = null;
        _dvaBankName = null;
        _dvaAccountName = null;
        _isLoadingDva = false;
        _dvaError = 'Network error: Unable to generate virtual account. Please try again.';
      });
    }
  }

  void _startBoundedPolling(String reference) {
    _pollingTimer?.cancel();
    _pollAttempts = 0;
    setState(() {
      _isPolling = true;
      _pollingTimedOut = false;
    });

    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      _pollAttempts++;

      if (_pollAttempts >= _maxPollAttempts) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _isPolling = false;
            _pollingTimedOut = true;
          });
        }
        return;
      }

      await _checkPaymentVerification(reference);
    });
  }

  Future<void> _checkPaymentVerification(String reference) async {
    final authState = ref.read(authViewModelProvider);
    final profileState = ref.read(profileViewModelProvider);
    final authRepo = ref.read(authRepositoryProvider);

    final phone = authState.phoneNumber?.isNotEmpty == true
        ? authState.phoneNumber!
        : (profileState.phoneNumber.isNotEmpty
            ? profileState.phoneNumber
            : (authRepo.getAuthenticatedPhone() ?? ''));
    final userPhone = phone.isNotEmpty ? phone : '+2348011111111';

    try {
      http.Response response;
      try {
        response = await defaultApiClient.post(
          '/v1/wallet/verify-funding',
          body: {
            'reference': reference,
            'phoneNumber': userPhone,
          },
        );
        if (response.statusCode != 200) {
          response = await defaultApiClient.get('/v1/payments/paystack/verify/$reference');
        }
      } catch (_) {
        response = await defaultApiClient.get('/v1/payments/paystack/verify/$reference');
      }

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final rawData = json['data'];
        final rawStatus = rawData is Map ? rawData['status'] : null;
        final topStatus = json['status'];
        final isSuccess = json['success'] == true ||
            topStatus == 'success' ||
            (topStatus == true && rawStatus == 'success') ||
            rawStatus == 'success';

        if (isSuccess) {
          _pollingTimer?.cancel();
          _executeConfirmedFunding(reference);
        } else if (rawStatus == 'failed' || topStatus == 'failed') {
          _pollingTimer?.cancel();
          if (mounted) {
            setState(() {
              _isPolling = false;
              if (_selectedMethod == 'Debit Card') {
                _cardError = 'Card payment was declined or failed on Paystack.';
              }
            });
          }
        }
      }
    } catch (_) {}
  }

  void _executeConfirmedFunding(String reference) {
    if (!mounted) return;

    ref.read(walletViewModelProvider.notifier).fundWallet(
          amount: _fundedAmount,
          method: _selectedMethod == 'Bank Transfer'
              ? 'Bank Transfer (DVA)'
              : 'Debit Card (Paystack)',
        );
    ref.read(walletViewModelProvider.notifier).fetchMeBalance();
    if (mounted) {
      setState(() {
        _isPolling = false;
        _step = 3;
      });
    }
  }

  Future<void> _confirmFunding() async {
    if (_selectedMethod == 'Bank Transfer') {
      if (_dvaReference != null) {
        _checkPaymentVerification(_dvaReference!);
      }
      return;
    }

    // Debit Card Payment Flow: Initialize on backend and open Paystack checkout
    setState(() {
      _isInitializingCard = true;
      _cardError = null;
      _pollingTimedOut = false;
    });

    final authState = ref.read(authViewModelProvider);
    final profileState = ref.read(profileViewModelProvider);
    final authRepo = ref.read(authRepositoryProvider);

    final phone = authState.phoneNumber?.isNotEmpty == true
        ? authState.phoneNumber!
        : (profileState.phoneNumber.isNotEmpty
            ? profileState.phoneNumber
            : (authRepo.getAuthenticatedPhone() ?? ''));
    final email = authState.email?.isNotEmpty == true
        ? authState.email!
        : (profileState.email.isNotEmpty ? profileState.email : '');

    final userPhone = phone.isNotEmpty ? phone : '+2348011111111';
    final userEmail = email.isNotEmpty
        ? email
        : 'user_${userPhone.replaceAll(RegExp(r'[^0-9]'), '')}@payflow.app';

    final txRef = 'PF_FUND_${DateTime.now().millisecondsSinceEpoch}_${userPhone.replaceAll(RegExp(r'[^0-9]'), '')}';
    _cardReference = txRef;

    try {
      http.Response response;
      try {
        response = await defaultApiClient.post(
          '/v1/wallet/initialize-funding',
          body: {
            'email': userEmail,
            'amount': _fundedAmount,
            'phoneNumber': userPhone,
          },
        );
      } catch (_) {
        response = await defaultApiClient.post(
          '/v1/payments/paystack/initialize',
          body: {
            'reference': txRef,
            'amount_in_kobo': (_fundedAmount * 100).toInt(),
            'payment_type': 'wallet_topup',
          },
        );
      }

      if (response.statusCode != 200) {
        response = await defaultApiClient.post(
          '/v1/payments/paystack/initialize',
          body: {
            'reference': txRef,
            'amount_in_kobo': (_fundedAmount * 100).toInt(),
            'payment_type': 'wallet_topup',
          },
        );
      }

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final rawData = json['data'];
        final Map<String, dynamic> data =
            rawData is Map<String, dynamic> ? rawData : (json is Map<String, dynamic> ? json : {});
        final authUrl = (data['authorization_url'] ?? json['authorization_url']) as String?;
        final refCode = (data['reference'] ?? json['reference'] ?? txRef) as String;

        if (authUrl != null && authUrl.isNotEmpty) {
          if (mounted) {
            setState(() {
              _cardReference = refCode;
              _cardAuthorizationUrl = authUrl;
              _isInitializingCard = false;
            });
          }

          // Launch real Paystack checkout page
          final uri = Uri.parse(authUrl);
          try {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } catch (_) {}

          // Start bounded polling to await real Paystack payment verification
          _startBoundedPolling(refCode);
          return;
        }
      }

      String errorMsg = 'Failed to initialize Paystack card checkout';
      try {
        final json = jsonDecode(response.body);
        errorMsg = json['message'] ?? json['error'] ?? errorMsg;
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isInitializingCard = false;
          _cardError = errorMsg;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializingCard = false;
          _cardError = 'Network error during card initialization: ${e.toString()}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_cardError!),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    }
  }

  void _copyAccountNumber() {
    if (_dvaAccountNumber != null) {
      Clipboard.setData(ClipboardData(text: _dvaAccountNumber!));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Virtual account $_dvaAccountNumber copied to clipboard'),
          backgroundColor: AppColors.income,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppDimensions.radiusLg),
          ),
        ),
        padding: const EdgeInsets.all(AppDimensions.spaceLg),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.spaceMd),

              if (_step == 1) ...[
                Text(
                  'Fund Wallet',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceSm),
                Text(
                  'Select a payment method and enter amount to top up.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppDimensions.spaceLg),

                // Method Selection
                Text(
                  'Funding Method',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceSm),
                Row(
                  children: [
                    Expanded(
                      child: _MethodCard(
                        title: 'Debit Card',
                        subtitle: 'Instant',
                        icon: Icons.credit_card_rounded,
                        isSelected: _selectedMethod == 'Debit Card',
                        onTap: () => setState(() => _selectedMethod = 'Debit Card'),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spaceMd),
                    Expanded(
                      child: _MethodCard(
                        title: 'Bank Transfer',
                        subtitle: 'Dedicated Account',
                        icon: Icons.account_balance_rounded,
                        isSelected: _selectedMethod == 'Bank Transfer',
                        onTap: () => setState(() => _selectedMethod = 'Bank Transfer'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spaceLg),

                // Amount Input
                PayFlowTextField(
                  label: 'Top Up Amount (₦)',
                  hintText: 'e.g. 5000',
                  keyboardType: TextInputType.number,
                  controller: _amountController,
                  errorText: _errorText,
                  prefixIcon: const Icon(Icons.numbers_rounded),
                ),
                const SizedBox(height: AppDimensions.spaceMd),

                // Quick Amount Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [1000.0, 5000.0, 10000.0, 20000.0].map((amt) {
                      return Padding(
                        padding: const EdgeInsets.only(right: AppDimensions.spaceSm),
                        child: ActionChip(
                          label: Text('₦${amt.toStringAsFixed(0)}'),
                          onPressed: () => _onQuickAmountSelected(amt),
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          side: BorderSide.none,
                          labelStyle: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceXl),

                PayFlowButton(
                  text: _selectedMethod == 'Bank Transfer' ? 'Generate Virtual Account' : 'Review Top Up',
                  icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                  onPressed: _proceedToReview,
                ),
              ] else if (_step == 2) ...[
                if (_selectedMethod == 'Bank Transfer') ...[
                  Text(
                    'Dedicated Virtual Account',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spaceSm),
                  Text(
                    'Transfer ₦${_fundedAmount.toStringAsFixed(2)} to your dedicated virtual account below to fund your wallet.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppDimensions.spaceLg),

                  if (_isLoadingDva) ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppDimensions.spaceXl),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ] else if (_dvaError != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppDimensions.spaceLg),
                      decoration: BoxDecoration(
                        color: AppColors.expense.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        border: Border.all(
                          color: AppColors.expense.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.expense, size: 36),
                          const SizedBox(height: AppDimensions.spaceSm),
                          Text(
                            _dvaError!,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.expense,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spaceMd),
                          PayFlowButton(
                            text: 'Retry Generation',
                            variant: PayFlowButtonVariant.outline,
                            onPressed: _fetchDedicatedAccount,
                          ),
                        ],
                      ),
                    ),
                  ] else if (_dvaAccountNumber != null) ...[
                    PayFlowCard(
                      padding: const EdgeInsets.all(AppDimensions.spaceLg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Bank Name',
                                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondaryLight),
                              ),
                              Text(
                                _dvaBankName ?? 'Wema Bank',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const Divider(height: AppDimensions.spaceLg),
                          Text(
                            'Virtual Account Number',
                            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondaryLight),
                          ),
                          const SizedBox(height: AppDimensions.spaceXs),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _dvaAccountNumber!,
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  letterSpacing: 2,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, color: AppColors.primary),
                                tooltip: 'Copy Account Number',
                                onPressed: _copyAccountNumber,
                              ),
                            ],
                          ),
                          const Divider(height: AppDimensions.spaceLg),
                          _DetailRow(
                            label: 'Account Name',
                            value: _dvaAccountName ?? 'PayFlow / Dedicated',
                          ),
                          const SizedBox(height: AppDimensions.spaceSm),
                          _DetailRow(
                            label: 'Expected Top Up',
                            value: '₦${_fundedAmount.toStringAsFixed(2)}',
                            isBold: true,
                            valueColor: AppColors.income,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spaceMd),

                    // Polling Status Banner
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.spaceMd),
                      decoration: BoxDecoration(
                        color: _isPolling
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : AppColors.pending.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      ),
                      child: Row(
                        children: [
                          if (_isPolling)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            const Icon(Icons.info_outline_rounded, color: AppColors.pending, size: 18),
                          const SizedBox(width: AppDimensions.spaceMd),
                          Expanded(
                            child: Text(
                              _isPolling
                                  ? 'Awaiting bank transfer confirmation... (Attempt $_pollAttempts/$_maxPollAttempts)'
                                  : (_pollingTimedOut
                                      ? 'Verification polling timed out. Tap "Check Status" once transfer is complete.'
                                      : 'Ready for transfer confirmation.'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: AppDimensions.spaceXl),

                  Row(
                    children: [
                      Expanded(
                        child: PayFlowButton(
                          text: 'Back',
                          variant: PayFlowButtonVariant.outline,
                          onPressed: () {
                            _pollingTimer?.cancel();
                            setState(() => _step = 1);
                          },
                        ),
                      ),
                      if (_dvaError == null && _dvaAccountNumber != null) ...[
                        const SizedBox(width: AppDimensions.spaceMd),
                        Expanded(
                          child: PayFlowButton(
                            text: _pollingTimedOut ? 'Check Status' : 'I Have Transferred',
                            onPressed: () {
                              if (_dvaReference != null) {
                                _checkPaymentVerification(_dvaReference!);
                              }
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ] else ...[
                  if (_cardAuthorizationUrl != null) ...[
                    // Card Checkout Active / Polling Step
                    Text(
                      'Complete Card Payment',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spaceSm),
                    Text(
                      'Paystack secure checkout page has been opened in your browser. Complete payment there, and your wallet will update automatically.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppDimensions.spaceLg),

                    PayFlowCard(
                      padding: const EdgeInsets.all(AppDimensions.spaceLg),
                      child: Column(
                        children: [
                          const _DetailRow(
                            label: 'Payment Method',
                            value: 'Debit Card (Paystack)',
                          ),
                          const Divider(height: AppDimensions.spaceLg),
                          _DetailRow(
                            label: 'Amount to Pay',
                            value: '₦${_fundedAmount.toStringAsFixed(2)}',
                            isBold: true,
                            valueColor: AppColors.income,
                          ),
                          const Divider(height: AppDimensions.spaceLg),
                          _DetailRow(
                            label: 'Transaction Ref',
                            value: _cardReference ?? 'N/A',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spaceLg),

                    if (_cardError != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppDimensions.spaceMd),
                        decoration: BoxDecoration(
                          color: AppColors.expense.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                          border: Border.all(
                            color: AppColors.expense.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _cardError!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.expense,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spaceMd),
                    ],

                    // Polling Status Banner
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.spaceMd),
                      decoration: BoxDecoration(
                        color: _isPolling
                            ? AppColors.primary.withValues(alpha: 0.08)
                            : (_pollingTimedOut
                                ? AppColors.pending.withValues(alpha: 0.1)
                                : AppColors.surfaceVariantLight),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        border: Border.all(
                          color: _isPolling
                              ? AppColors.primary.withValues(alpha: 0.2)
                              : (_pollingTimedOut
                                  ? AppColors.pending.withValues(alpha: 0.3)
                                  : AppColors.borderLight),
                        ),
                      ),
                      child: Row(
                        children: [
                          if (_isPolling)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else if (_pollingTimedOut)
                            const Icon(Icons.timer_outlined, color: AppColors.pending, size: 18)
                          else
                            const Icon(Icons.info_outline_rounded, color: AppColors.pending, size: 18),
                          const SizedBox(width: AppDimensions.spaceMd),
                          Expanded(
                            child: Text(
                              _isPolling
                                  ? 'Awaiting Paystack card confirmation... (Attempt $_pollAttempts/$_maxPollAttempts)'
                                  : (_pollingTimedOut
                                      ? 'Verification timed out. Tap "Check Status" once completed on Paystack.'
                                      : 'Ready for verification.'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spaceLg),

                    Row(
                      children: [
                        Expanded(
                          child: PayFlowButton(
                            text: 'Re-open Page',
                            variant: PayFlowButtonVariant.outline,
                            icon: const Icon(Icons.open_in_new_rounded, size: 16),
                            onPressed: () async {
                              if (_cardAuthorizationUrl != null) {
                                final uri = Uri.parse(_cardAuthorizationUrl!);
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: AppDimensions.spaceMd),
                        Expanded(
                          child: PayFlowButton(
                            text: _pollingTimedOut ? 'Check Status' : 'I Have Paid',
                            onPressed: () {
                              if (_cardReference != null) {
                                _checkPaymentVerification(_cardReference!);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spaceSm),
                    Center(
                      child: TextButton(
                        onPressed: () {
                          _pollingTimer?.cancel();
                          setState(() {
                            _cardAuthorizationUrl = null;
                            _cardReference = null;
                            _isPolling = false;
                            _cardError = null;
                            _step = 1;
                          });
                        },
                        child: Text(
                          'Cancel & Return',
                          style: TextStyle(color: theme.textTheme.bodySmall?.color),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Pre-checkout Card Review
                    Text(
                      'Confirm Top Up',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spaceSm),
                    Text(
                      'Please review your wallet top-up details before proceeding to Paystack checkout.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppDimensions.spaceLg),

                    PayFlowCard(
                      padding: const EdgeInsets.all(AppDimensions.spaceLg),
                      child: Column(
                        children: [
                          _DetailRow(
                            label: 'Funding Method',
                            value: _selectedMethod,
                          ),
                          const Divider(height: AppDimensions.spaceLg),
                          const _DetailRow(
                            label: 'Payment Gateway',
                            value: 'Paystack (Secure 3DS)',
                          ),
                          const Divider(height: AppDimensions.spaceLg),
                          _DetailRow(
                            label: 'Top Up Amount',
                            value: '₦${_fundedAmount.toStringAsFixed(2)}',
                            isBold: true,
                            valueColor: AppColors.income,
                          ),
                          const Divider(height: AppDimensions.spaceLg),
                          const _DetailRow(
                            label: 'Transaction Fee',
                            value: 'Free (₦0.00)',
                            valueColor: AppColors.income,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spaceXl),

                    Row(
                      children: [
                        Expanded(
                          child: PayFlowButton(
                            text: 'Back',
                            variant: PayFlowButtonVariant.outline,
                            onPressed: () => setState(() => _step = 1),
                          ),
                        ),
                        const SizedBox(width: AppDimensions.spaceMd),
                        Expanded(
                          child: PayFlowButton(
                            text: _isInitializingCard ? 'Connecting...' : 'Pay with Paystack',
                            icon: _isInitializingCard
                                ? null
                                : const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 16),
                            onPressed: _isInitializingCard ? null : _confirmFunding,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ] else ...[
                // Success Step
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppDimensions.spaceLg),
                        decoration: const BoxDecoration(
                          color: AppColors.income,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: AppDimensions.iconLg,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spaceMd),
                      Text(
                        'Top Up Successful!',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.income,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spaceSm),
                      Text(
                        '₦${_fundedAmount.toStringAsFixed(2)} added to your main wallet balance.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppDimensions.spaceLg),
                      PayFlowButton(
                        text: 'Done',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _MethodCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppDimensions.spaceMd),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : theme.cardColor,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(
            color: isSelected ? AppColors.primary : theme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : theme.iconTheme.color,
            ),
            const SizedBox(height: AppDimensions.spaceXs),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 9,
                color: isSelected ? AppColors.primary : AppColors.income,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium,
        ),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? theme.textTheme.titleMedium?.color,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
