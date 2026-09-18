import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/payflow_button.dart';
import '../../../core/widgets/payflow_card.dart';
import '../../../core/widgets/transaction_pin_bottom_sheet.dart';
import '../../wallet/view_models/wallet_view_model.dart';

class ServiceReviewSheet extends ConsumerStatefulWidget {
  final String serviceTitle;
  final IconData serviceIcon;
  final Color iconColor;
  final String providerName;
  final String identifier;
  final String identifierLabel;
  final String planOrDetail;
  final double amount;
  final double fee;
  final Future<void> Function(BuildContext context, WidgetRef ref) onConfirm;

  const ServiceReviewSheet({
    super.key,
    required this.serviceTitle,
    required this.serviceIcon,
    required this.iconColor,
    required this.providerName,
    required this.identifier,
    required this.identifierLabel,
    required this.planOrDetail,
    required this.amount,
    this.fee = 0.00,
    required this.onConfirm,
  });

  static Future<void> show({
    required BuildContext context,
    required String serviceTitle,
    required IconData serviceIcon,
    required Color iconColor,
    required String providerName,
    required String identifier,
    required String identifierLabel,
    required String planOrDetail,
    required double amount,
    double fee = 0.00,
    required Future<void> Function(BuildContext context, WidgetRef ref) onConfirm,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ServiceReviewSheet(
        serviceTitle: serviceTitle,
        serviceIcon: serviceIcon,
        iconColor: iconColor,
        providerName: providerName,
        identifier: identifier,
        identifierLabel: identifierLabel,
        planOrDetail: planOrDetail,
        amount: amount,
        fee: fee,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  ConsumerState<ServiceReviewSheet> createState() => _ServiceReviewSheetState();
}

class _ServiceReviewSheetState extends ConsumerState<ServiceReviewSheet> {
  bool _isProcessing = false;
  String? _errorMessage;
  bool _saveBeneficiary = true;

  Future<void> _handleConfirm() async {
    if (_isProcessing) return;

    final total = widget.amount + widget.fee;
    final verified = await TransactionPinBottomSheet.show(
      context: context,
      amount: total,
      recipient: widget.providerName,
    );

    if (verified != true) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      if (_saveBeneficiary && defaultApiClient.baseUrl.isNotEmpty) {
        try {
          defaultApiClient.post('/v1/users/beneficiaries', body: {
            'name': widget.providerName,
            'accountNumber': widget.identifier,
            'category': widget.serviceTitle.toLowerCase().contains('airtime')
                ? 'airtime'
                : 'bills',
            'serviceId': widget.serviceTitle,
            'phone': widget.identifier,
          });
        } catch (_) {}
      }

      if (!mounted) return;
      await widget.onConfirm(context, ref);
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final walletState = ref.watch(walletViewModelProvider);
    final total = widget.amount + widget.fee;
    final hasEnoughBalance = total <= walletState.mainBalance;

    return Container(
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
            const SizedBox(height: AppDimensions.spaceLg),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppDimensions.spaceSm + 2),
                  decoration: BoxDecoration(
                    color: widget.iconColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.serviceIcon, color: widget.iconColor, size: AppDimensions.iconMd),
                ),
                const SizedBox(width: AppDimensions.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Review Payment',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.serviceTitle,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spaceLg),

            PayFlowCard(
              padding: const EdgeInsets.all(AppDimensions.spaceLg),
              child: Column(
                children: [
                  _ReviewRow(label: 'Provider', value: widget.providerName),
                  const Divider(height: AppDimensions.spaceLg),
                  _ReviewRow(label: widget.identifierLabel, value: widget.identifier),
                  const Divider(height: AppDimensions.spaceLg),
                  _ReviewRow(label: 'Plan / Details', value: widget.planOrDetail),
                  const Divider(height: AppDimensions.spaceLg),
                  _ReviewRow(label: 'Amount', value: '₦${widget.amount.toStringAsFixed(2)}'),
                  const Divider(height: AppDimensions.spaceLg),
                  _ReviewRow(label: 'Service Fee', value: '₦${widget.fee.toStringAsFixed(2)}'),
                  const Divider(height: AppDimensions.spaceLg),
                  _ReviewRow(
                    label: 'Total Payable',
                    value: '₦${total.toStringAsFixed(2)}',
                    isBold: true,
                    valueColor: AppColors.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spaceSm),

            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Available Wallet: ₦${walletState.mainBalance.toStringAsFixed(2)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 12,
                  color: hasEnoughBalance ? AppColors.income : AppColors.expense,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (!hasEnoughBalance) ...[
              const SizedBox(height: AppDimensions.spaceSm),
              Container(
                padding: const EdgeInsets.all(AppDimensions.spaceSm + 2),
                decoration: BoxDecoration(
                  color: AppColors.expense.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.expense, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Insufficient wallet balance for this purchase.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          color: AppColors.expense,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: AppDimensions.spaceSm),
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
                        _errorMessage!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          color: AppColors.expense,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _isProcessing ? null : _handleConfirm,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Retry',
                        style: TextStyle(
                          color: AppColors.expense,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Save as Beneficiary Toggle Card
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spaceMd,
                vertical: AppDimensions.spaceSm,
              ),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.bookmark_add_outlined,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppDimensions.spaceSm),
                      Text(
                        'Save as beneficiary',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Switch.adaptive(
                    value: _saveBeneficiary,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) {
                      setState(() {
                        _saveBeneficiary = val;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spaceLg),

            Row(
              children: [
                Expanded(
                  child: PayFlowButton(
                    text: 'Cancel',
                    variant: PayFlowButtonVariant.outline,
                    onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: AppDimensions.spaceMd),
                Expanded(
                  child: PayFlowButton(
                    text: 'Confirm & Pay',
                    isLoading: _isProcessing,
                    icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                    onPressed: (hasEnoughBalance && !_isProcessing) ? _handleConfirm : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;

  const _ReviewRow({
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
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 13,
            color: isBold ? theme.textTheme.titleMedium?.color : null,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        const SizedBox(width: AppDimensions.spaceSm),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? theme.textTheme.titleMedium?.color,
            ),
          ),
        ),
      ],
    );
  }
}
