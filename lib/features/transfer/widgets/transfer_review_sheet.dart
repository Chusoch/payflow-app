import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/payflow_button.dart';
import '../../../core/widgets/payflow_card.dart';
import '../../../core/widgets/transaction_pin_bottom_sheet.dart';
import '../view_models/transfer_view_model.dart';

class TransferReviewSheet extends ConsumerStatefulWidget {
  final String recipientName;
  final String recipientIdentifier;
  final String transferType;
  final String? bankName;
  final double amount;
  final String narration;
  final VoidCallback onConfirm;

  const TransferReviewSheet({
    super.key,
    required this.recipientName,
    required this.recipientIdentifier,
    required this.transferType,
    this.bankName,
    required this.amount,
    required this.narration,
    required this.onConfirm,
  });

  static Future<void> show({
    required BuildContext context,
    required String recipientName,
    required String recipientIdentifier,
    required String transferType,
    String? bankName,
    required double amount,
    required String narration,
    required VoidCallback onConfirm,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TransferReviewSheet(
        recipientName: recipientName,
        recipientIdentifier: recipientIdentifier,
        transferType: transferType,
        bankName: bankName,
        amount: amount,
        narration: narration,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  ConsumerState<TransferReviewSheet> createState() => _TransferReviewSheetState();
}

class _TransferReviewSheetState extends ConsumerState<TransferReviewSheet> {
  bool _saveBeneficiary = true;

  Future<void> _handleConfirm() async {
    final verified = await TransactionPinBottomSheet.show(
      context: context,
      amount: widget.amount,
      recipient: widget.recipientName,
    );

    if (verified != true) return;

    if (!mounted) return;
    Navigator.of(context).pop();

    if (_saveBeneficiary) {
      ref.read(transferViewModelProvider.notifier).saveBeneficiary(
        Beneficiary(
          id: 'b_${DateTime.now().millisecondsSinceEpoch}',
          name: widget.recipientName,
          accountOrPhone: widget.recipientIdentifier,
          bankName: widget.bankName ??
              (widget.transferType == 'Bank Account'
                  ? 'Bank Account'
                  : 'PayFlow Account'),
          category: widget.transferType == 'Bank Account' ? 'bank' : 'p2p',
        ),
      );
    }

    widget.onConfirm();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transferState = ref.watch(transferViewModelProvider);

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
            const SizedBox(height: AppDimensions.spaceMd),

            Text(
              'Review Transfer',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppDimensions.spaceSm),
            Text(
              'Please confirm the transfer details before proceeding.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppDimensions.spaceLg),

            if (transferState.errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(AppDimensions.spaceMd),
                decoration: BoxDecoration(
                  color: AppColors.expense.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  border: Border.all(color: AppColors.expense.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.expense),
                    const SizedBox(width: AppDimensions.spaceSm),
                    Expanded(
                      child: Text(
                        transferState.errorMessage!,
                        style: const TextStyle(fontSize: 12, color: AppColors.expense),
                      ),
                    ),
                    TextButton(
                      onPressed: _handleConfirm,
                      child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.spaceLg),
            ],

            // Review Card
            PayFlowCard(
              padding: const EdgeInsets.all(AppDimensions.spaceLg),
              child: Column(
                children: [
                  _ReviewRow(
                    label: 'Recipient',
                    value: widget.recipientName,
                    isBold: true,
                  ),
                  if (widget.bankName != null && widget.bankName!.isNotEmpty) ...[
                    const Divider(height: AppDimensions.spaceLg),
                    _ReviewRow(
                      label: 'Destination Bank',
                      value: widget.bankName!,
                      isBold: true,
                    ),
                  ],
                  const Divider(height: AppDimensions.spaceLg),
                  _ReviewRow(
                    label: widget.transferType == 'PayFlow User' ? 'Phone / Account' : 'Account Number',
                    value: widget.recipientIdentifier,
                  ),
                  const Divider(height: AppDimensions.spaceLg),
                  _ReviewRow(
                    label: 'Transfer Method',
                    value: widget.bankName != null ? '${widget.transferType} (${widget.bankName})' : widget.transferType,
                  ),
                  const Divider(height: AppDimensions.spaceLg),
                  _ReviewRow(
                    label: 'Transfer Amount',
                    value: '₦${widget.amount.toStringAsFixed(2)}',
                    isBold: true,
                    valueColor: AppColors.primary,
                  ),
                  const Divider(height: AppDimensions.spaceLg),
                  const _ReviewRow(
                    label: 'Transfer Fee',
                    value: 'Free (₦0.00)',
                    valueColor: AppColors.income,
                  ),
                  if (widget.narration.isNotEmpty) ...[
                    const Divider(height: AppDimensions.spaceLg),
                    _ReviewRow(
                      label: 'Narration',
                      value: widget.narration,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spaceMd),

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
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: AppDimensions.spaceMd),
                Expanded(
                  child: PayFlowButton(
                    text: 'Confirm & Send',
                    isLoading: transferState.isProcessing,
                    onPressed: _handleConfirm,
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
            fontSize: 12,
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
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
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              fontSize: 13,
              color: valueColor ?? theme.textTheme.titleMedium?.color,
            ),
          ),
        ),
      ],
    );
  }
}
