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

class ElectricityFlowSheet extends ConsumerStatefulWidget {
  final String? initialMeter;
  final String? initialDisco;

  const ElectricityFlowSheet({
    super.key,
    this.initialMeter,
    this.initialDisco,
  });

  static Future<void> show(
    BuildContext context, {
    String? initialMeter,
    String? initialDisco,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ElectricityFlowSheet(
        initialMeter: initialMeter,
        initialDisco: initialDisco,
      ),
    );
  }

  @override
  ConsumerState<ElectricityFlowSheet> createState() => _ElectricityFlowSheetState();
}

class _ElectricityFlowSheetState extends ConsumerState<ElectricityFlowSheet> {
  late final TextEditingController _meterController;
  final _amountController = TextEditingController();

  late String _selectedDisco;
  String _selectedMeterType = 'Prepaid';
  String? _meterError;
  String? _amountError;

  bool _isVerifyingMeter = false;
  Map<String, dynamic>? _verifiedCustomer;
  String? _verificationError;

  @override
  void initState() {
    super.initState();
    _meterController = TextEditingController(
      text: widget.initialMeter ?? '0192837465',
    );
    _selectedDisco = widget.initialDisco ?? 'Ikeja Electric';

    if (widget.initialMeter != null && widget.initialMeter!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleVerifyMeter();
      });
    }
  }

  @override
  void dispose() {
    _meterController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _handleVerifyMeter() async {
    final meter = _meterController.text.trim();
    if (meter.isEmpty || !RegExp(r'^\d+$').hasMatch(meter)) {
      setState(() => _meterError = 'Enter a valid numeric meter number');
      return;
    }

    setState(() {
      _isVerifyingMeter = true;
      _verificationError = null;
      _meterError = null;
    });

    try {
      final res = await ref.read(servicesViewModelProvider.notifier).verifyMeter(
            meterNumber: meter,
            disco: _selectedDisco,
            type: _selectedMeterType,
          );
      setState(() {
        _isVerifyingMeter = false;
        _verifiedCustomer = res;
      });
    } catch (e) {
      setState(() {
        _isVerifyingMeter = false;
        _verifiedCustomer = null;
        _verificationError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _proceedToReview() {
    final meter = _meterController.text.trim();
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText) ?? 0.0;

    bool isValid = true;
    if (meter.isEmpty || !RegExp(r'^\d+$').hasMatch(meter)) {
      setState(() => _meterError = 'Enter a valid meter number');
      isValid = false;
    }

    if (_verifiedCustomer == null) {
      _handleVerifyMeter();
      return;
    }

    if (amount <= 0) {
      setState(() => _amountError = 'Enter a valid amount greater than ₦0');
      isValid = false;
    }

    if (!isValid) return;

    final customerName = _verifiedCustomer!['customerName'] as String? ?? 'Verified Customer';

    final rootContext = context;
    Navigator.of(context).pop();

    ServiceReviewSheet.show(
      context: rootContext,
      serviceTitle: 'Electricity Bill Payment',
      serviceIcon: Icons.bolt_rounded,
      iconColor: const Color(0xFFF59E0B),
      providerName: '$_selectedDisco ($customerName)',
      identifier: meter,
      identifierLabel: 'Meter Number',
      planOrDetail: 'Meter Type: $_selectedMeterType',
      amount: amount,
      onConfirm: (reviewContext, ref) async {
        const generatedToken = '4920-1849-2048-1039';
        final verification = await ref.read(walletViewModelProvider.notifier).payService(
              title: 'Electricity ($_selectedDisco)',
              category: 'Electricity',
              amount: amount,
              identifier: '$meter ($_selectedMeterType)',
              referencePrefix: 'PF-ELEC-',
              token: generatedToken,
              narration: 'Prepaid Token Recharge for $customerName',
              providerType: PaymentProviderType.vtpass,
            );

        if (!verification.isConfirmed) {
          throw Exception(verification.failureReason ?? 'Insufficient wallet balance for this electricity bill payment.');
        }

        if (!reviewContext.mounted) return;
        final parentContext = Navigator.of(reviewContext).context;
        Navigator.of(reviewContext).pop();

        ServiceResultSheet.show(
          context: parentContext,
          isSuccess: true,
          serviceTitle: 'Electricity Bill Payment',
          providerName: '$_selectedDisco ($customerName)',
          identifier: meter,
          amount: amount,
          reference: verification.transactionRef,
          token: generatedToken,
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
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    color: Color(0xFFF59E0B),
                    size: AppDimensions.iconMd,
                  ),
                ),
                const SizedBox(width: AppDimensions.spaceMd),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pay Electricity',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Prepaid & Postpaid Disco bills',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spaceLg),

            // Disco Dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedDisco,
              decoration: InputDecoration(
                labelText: 'Select Disco Provider',
                prefixIcon: const Icon(Icons.business_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
              ),
              items: servicesState.electricityDiscos
                  .map((disco) => DropdownMenuItem(value: disco, child: Text(disco)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedDisco = val);
              },
            ),
            const SizedBox(height: AppDimensions.spaceLg),

            // Meter Type Selector (Prepaid vs Postpaid)
            Text(
              'Meter Type',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: AppDimensions.spaceSm),

            Row(
              children: servicesState.meterTypes.map((type) {
                final isSelected = _selectedMeterType == type;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedMeterType = type),
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
                          type,
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

            // Meter Number Input
            PayFlowTextField(
              label: 'Meter Number',
              hintText: 'Enter 10-13 digit meter number',
              keyboardType: TextInputType.number,
              controller: _meterController,
              errorText: _meterError,
              prefixIcon: const Icon(Icons.numbers_rounded),
              onChanged: (val) {
                if (_meterError != null || _verifiedCustomer != null || _verificationError != null) {
                  setState(() {
                    _meterError = null;
                    _verifiedCustomer = null;
                    _verificationError = null;
                  });
                }
              },
            ),
            const SizedBox(height: AppDimensions.spaceSm),

            // Meter Verification Status Card & Action
            if (_isVerifyingMeter)
              Container(
                padding: const EdgeInsets.all(AppDimensions.spaceSm + 2),
                child: const Row(
                  children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('Verifying meter number with VTPass...', style: TextStyle(fontSize: 12)),
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
                      onPressed: _handleVerifyMeter,
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
                            'Address: ${_verifiedCustomer!['address']}',
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
                  onPressed: _handleVerifyMeter,
                  icon: const Icon(Icons.verified_user_rounded, size: 16),
                  label: const Text('Verify Meter Number', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),

            const SizedBox(height: AppDimensions.spaceLg),

            // Amount Input
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
