import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/payflow_button.dart';
import '../../../core/widgets/payflow_text_field.dart';
import '../../../core/payment/providers/payment_provider.dart';
import '../../wallet/view_models/wallet_view_model.dart';
import '../view_models/services_view_model.dart';
import 'service_result_sheet.dart';
import 'service_review_sheet.dart';

class CableTvFlowSheet extends ConsumerStatefulWidget {
  final String? initialSmartcard;
  final String? initialProvider;

  const CableTvFlowSheet({
    super.key,
    this.initialSmartcard,
    this.initialProvider,
  });

  static Future<void> show(
    BuildContext context, {
    String? initialSmartcard,
    String? initialProvider,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CableTvFlowSheet(
        initialSmartcard: initialSmartcard,
        initialProvider: initialProvider,
      ),
    );
  }

  @override
  ConsumerState<CableTvFlowSheet> createState() => _CableTvFlowSheetState();
}

class _CableTvFlowSheetState extends ConsumerState<CableTvFlowSheet> {
  late final TextEditingController _smartcardController;
  late String _selectedProvider;
  CablePackage? _selectedPackage;
  String? _smartcardError;
  String? _packageError;

  bool _isVerifyingSmartcard = false;
  Map<String, dynamic>? _verifiedCustomer;
  String? _verificationError;

  @override
  void initState() {
    super.initState();
    _smartcardController = TextEditingController(
      text: widget.initialSmartcard ?? '1029384756',
    );
    _selectedProvider = widget.initialProvider ?? 'DSTV';

    if (widget.initialSmartcard != null && widget.initialSmartcard!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleVerifySmartcard();
      });
    }
  }

  @override
  void dispose() {
    _smartcardController.dispose();
    super.dispose();
  }

  Future<void> _handleVerifySmartcard() async {
    final smartcard = _smartcardController.text.trim();
    if (smartcard.isEmpty || !RegExp(r'^\d+$').hasMatch(smartcard)) {
      setState(() => _smartcardError = 'Enter a valid numeric Smartcard / IUC number');
      return;
    }

    setState(() {
      _isVerifyingSmartcard = true;
      _verificationError = null;
      _smartcardError = null;
    });

    try {
      final res = await ref.read(servicesViewModelProvider.notifier).verifySmartcard(
            smartcardNumber: smartcard,
            provider: _selectedProvider,
          );
      setState(() {
        _isVerifyingSmartcard = false;
        _verifiedCustomer = res;
      });
    } catch (e) {
      setState(() {
        _isVerifyingSmartcard = false;
        _verifiedCustomer = null;
        _verificationError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _proceedToReview() {
    final smartcard = _smartcardController.text.trim();

    bool isValid = true;
    if (smartcard.isEmpty || !RegExp(r'^\d+$').hasMatch(smartcard)) {
      setState(() => _smartcardError = 'Enter a valid Smartcard / IUC number');
      isValid = false;
    }

    if (_verifiedCustomer == null) {
      _handleVerifySmartcard();
      return;
    }

    if (_selectedPackage == null) {
      setState(() => _packageError = 'Please select a subscription package');
      isValid = false;
    }

    if (!isValid) return;

    final customerName = _verifiedCustomer!['customerName'] as String? ?? 'Verified Subscriber';
    final package = _selectedPackage!;
    final rootContext = context;
    Navigator.of(context).pop();

    ServiceReviewSheet.show(
      context: rootContext,
      serviceTitle: 'Cable TV Subscription',
      serviceIcon: Icons.tv_rounded,
      iconColor: const Color(0xFF8B5CF6),
      providerName: '$_selectedProvider ($customerName)',
      identifier: smartcard,
      identifierLabel: 'Smartcard / IUC',
      planOrDetail: package.packageName,
      amount: package.price,
      onConfirm: (reviewContext, ref) async {
        final verification = await ref.read(walletViewModelProvider.notifier).payService(
              title: 'Cable TV (${package.packageName})',
              category: 'Cable',
              amount: package.price,
              identifier: smartcard,
              referencePrefix: 'PF-CABLE-',
              narration: '$_selectedProvider ${package.packageName} for $customerName',
              providerType: PaymentProviderType.vtpass,
            );

        if (!verification.isConfirmed) {
          throw Exception(verification.failureReason ?? 'Insufficient wallet balance for this Cable TV subscription.');
        }

        if (!reviewContext.mounted) return;
        final parentContext = Navigator.of(reviewContext).context;
        Navigator.of(reviewContext).pop();

        ServiceResultSheet.show(
          context: parentContext,
          isSuccess: true,
          serviceTitle: 'Cable TV Subscription',
          providerName: '$_selectedProvider ($customerName)',
          identifier: smartcard,
          amount: package.price,
          reference: verification.transactionRef,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servicesState = ref.watch(servicesViewModelProvider);
    final walletState = ref.watch(walletViewModelProvider);
    final availablePackages = servicesState.cablePackages[_selectedProvider] ?? [];

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusLg),
        ),
      ),
      padding: EdgeInsets.only(
        left: AppDimensions.spaceLg,
        right: AppDimensions.spaceLg,
        top: AppDimensions.spaceLg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppDimensions.spaceLg,
      ),
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
            const SizedBox(height: AppDimensions.spaceLg),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppDimensions.spaceSm + 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.tv_rounded,
                    color: Color(0xFF8B5CF6),
                    size: AppDimensions.iconMd,
                  ),
                ),
                const SizedBox(width: AppDimensions.spaceMd),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cable TV Subscription',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'DSTV, GOtv & Startimes packages',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spaceLg),

            // Cable Provider Selector
            Text(
              'Select Provider',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: AppDimensions.spaceSm),

            Row(
              children: servicesState.cableProviders.map((prov) {
                final isSelected = _selectedProvider == prov;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedProvider = prov;
                        _selectedPackage = null;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(vertical: AppDimensions.spaceSm + 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : theme.dividerColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          prov,
                          style: TextStyle(
                            color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppDimensions.spaceLg),

            // Smartcard / IUC Input
            PayFlowTextField(
              label: 'Smartcard / IUC Number',
              hintText: 'Enter 10-digit smartcard number',
              keyboardType: TextInputType.number,
              controller: _smartcardController,
              errorText: _smartcardError,
              prefixIcon: const Icon(Icons.credit_card_rounded),
              onChanged: (val) {
                if (_smartcardError != null || _verifiedCustomer != null || _verificationError != null) {
                  setState(() {
                    _smartcardError = null;
                    _verifiedCustomer = null;
                    _verificationError = null;
                  });
                }
              },
            ),
            const SizedBox(height: AppDimensions.spaceSm),

            // Smartcard Verification Status Card & Action
            if (_isVerifyingSmartcard)
              Container(
                padding: const EdgeInsets.all(AppDimensions.spaceSm + 2),
                child: const Row(
                  children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('Verifying smartcard with VTPass...', style: TextStyle(fontSize: 12)),
                  ],
                ),
              )
            else if (_verificationError != null)
              Container(
                padding: const EdgeInsets.all(AppDimensions.spaceSm + 2),
                decoration: BoxDecoration(
                  color: AppColors.expense.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  border: Border.all(color: AppColors.expense.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.expense, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _verificationError!,
                        style: const TextStyle(fontSize: 12, color: AppColors.expense),
                      ),
                    ),
                    TextButton(
                      onPressed: _handleVerifySmartcard,
                      child: const Text('Retry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              )
            else if (_verifiedCustomer != null)
              Container(
                padding: const EdgeInsets.all(AppDimensions.spaceSm + 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _verifiedCustomer!['customerName'] as String,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            'Package: ${_verifiedCustomer!['currentPackage']}',
                            style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _handleVerifySmartcard,
                  icon: const Icon(Icons.verified_user_rounded, size: 16),
                  label: const Text('Verify Smartcard', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),

            const SizedBox(height: AppDimensions.spaceLg),

            // Subscription Package List
            Text(
              'Select Package',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            if (_packageError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _packageError!,
                  style: const TextStyle(color: AppColors.expense, fontSize: 12),
                ),
              ),
            const SizedBox(height: AppDimensions.spaceSm),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: availablePackages.length,
              separatorBuilder: (context, index) => const SizedBox(height: AppDimensions.spaceSm),
              itemBuilder: (context, index) {
                final pkg = availablePackages[index];
                final isSelected = _selectedPackage?.id == pkg.id;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPackage = pkg;
                      _packageError = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(AppDimensions.spaceMd),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : theme.dividerColor.withValues(alpha: 0.4),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          pkg.packageName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '₦${pkg.price.toStringAsFixed(2)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? AppColors.primary : theme.textTheme.titleMedium?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Available: ₦${walletState.mainBalance.toStringAsFixed(2)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 11,
                  color: AppColors.income,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spaceXl),

            PayFlowButton(
              text: 'Continue to Review',
              icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              onPressed: _proceedToReview,
            ),
          ],
        ),
      ),
    );
  }
}
