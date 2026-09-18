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

class AirtimeFlowSheet extends ConsumerStatefulWidget {
  final String? initialPhone;
  final String? initialNetwork;

  const AirtimeFlowSheet({
    super.key,
    this.initialPhone,
    this.initialNetwork,
  });

  static Future<void> show(
    BuildContext context, {
    String? initialPhone,
    String? initialNetwork,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AirtimeFlowSheet(
        initialPhone: initialPhone,
        initialNetwork: initialNetwork,
      ),
    );
  }

  @override
  ConsumerState<AirtimeFlowSheet> createState() => _AirtimeFlowSheetState();
}

class _AirtimeFlowSheetState extends ConsumerState<AirtimeFlowSheet> {
  late final TextEditingController _phoneController;
  final _amountController = TextEditingController();

  late String _selectedNetwork;
  double? _selectedAmount;
  String? _phoneError;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(
      text: widget.initialPhone ?? '08123456789',
    );
    _selectedNetwork = widget.initialNetwork ?? 'MTN';
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _onQuickChipSelected(double amount) {
    setState(() {
      _selectedAmount = amount;
      _amountController.text = amount.toStringAsFixed(0);
      _amountError = null;
    });
  }

  void _proceedToReview() {
    final phone = _phoneController.text.trim();
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText) ?? 0.0;

    bool isValid = true;
    if (phone.length != 11 || !RegExp(r'^\d{11}$').hasMatch(phone)) {
      setState(() => _phoneError = 'Enter a valid 11-digit Nigerian phone number');
      isValid = false;
    }

    if (amount <= 0) {
      setState(() => _amountError = 'Enter a valid amount greater than ₦0');
      isValid = false;
    }

    if (!isValid) return;

    final rootContext = context;
    Navigator.of(context).pop();

    ServiceReviewSheet.show(
      context: rootContext,
      serviceTitle: 'Airtime Purchase',
      serviceIcon: Icons.phone_android_rounded,
      iconColor: const Color(0xFF3B82F6),
      providerName: _selectedNetwork,
      identifier: phone,
      identifierLabel: 'Phone Number',
      planOrDetail: 'Mobile Airtime Recharge',
      amount: amount,
      onConfirm: (reviewContext, ref) async {
        final verification = await ref.read(walletViewModelProvider.notifier).payService(
              title: 'Airtime Recharge ($_selectedNetwork)',
              category: 'Airtime',
              amount: amount,
              identifier: phone,
              referencePrefix: 'PF-AIR-',
              narration: '$_selectedNetwork Airtime ₦${amount.toStringAsFixed(0)}',
              providerType: PaymentProviderType.vtpass,
            );

        if (!verification.isConfirmed) {
          throw Exception(verification.failureReason ?? 'Insufficient wallet balance for this airtime recharge.');
        }

        if (!reviewContext.mounted) return;
        final parentContext = Navigator.of(reviewContext).context;
        Navigator.of(reviewContext).pop();

        ServiceResultSheet.show(
          context: parentContext,
          isSuccess: true,
          serviceTitle: 'Airtime Recharge',
          providerName: _selectedNetwork,
          identifier: phone,
          amount: amount,
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
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.phone_android_rounded,
                    color: Color(0xFF3B82F6),
                    size: AppDimensions.iconMd,
                  ),
                ),
                const SizedBox(width: AppDimensions.spaceMd),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Buy Airtime',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Instant mobile network top-up',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spaceLg),

            // Select Network Provider
            Text(
              'Select Network',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: AppDimensions.spaceSm),

            Row(
              children: servicesState.networks.map((net) {
                final isSelected = _selectedNetwork == net;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedNetwork = net),
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
                          net,
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

            // Phone Number Input
            PayFlowTextField(
              label: 'Phone Number',
              hintText: 'e.g. 08123456789',
              keyboardType: TextInputType.phone,
              controller: _phoneController,
              errorText: _phoneError,
              prefixIcon: const Icon(Icons.phone_rounded),
              onChanged: (val) {
                if (_phoneError != null) setState(() => _phoneError = null);
              },
            ),
            const SizedBox(height: AppDimensions.spaceLg),

            // Quick Amount Chips
            Text(
              'Select Amount',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: AppDimensions.spaceSm),

            Row(
              children: [100.0, 200.0, 500.0, 1000.0].map((amt) {
                final isSelected = _selectedAmount == amt;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text('₦${amt.toStringAsFixed(0)}'),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) _onQuickChipSelected(amt);
                      },
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 11,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppDimensions.spaceSm),

            // Custom Amount Input
            PayFlowTextField(
              label: 'Amount (₦)',
              hintText: '0.00',
              keyboardType: TextInputType.number,
              controller: _amountController,
              errorText: _amountError,
              prefixIcon: const Icon(Icons.numbers_rounded),
              onChanged: (val) {
                if (_amountError != null) setState(() => _amountError = null);
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
