import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/payflow_button.dart';
import '../../../core/widgets/payflow_card.dart';
import '../../home/models/transaction_item.dart';
import '../../wallet/widgets/transaction_detail_sheet.dart';

class TransferResultSheet extends StatelessWidget {
  final bool isSuccess;
  final String recipientName;
  final double amount;
  final String? reference;
  final String? narration;
  final String? senderName;
  final String? errorMessage;
  final VoidCallback? onDone;
  final VoidCallback? onRetry;

  const TransferResultSheet({
    super.key,
    required this.isSuccess,
    required this.recipientName,
    required this.amount,
    this.reference,
    this.narration,
    this.senderName,
    this.errorMessage,
    this.onDone,
    this.onRetry,
  });

  static Future<void> show({
    required BuildContext context,
    required bool isSuccess,
    required String recipientName,
    required double amount,
    String? reference,
    String? narration,
    String? senderName,
    String? errorMessage,
    VoidCallback? onDone,
    VoidCallback? onRetry,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => TransferResultSheet(
        isSuccess: isSuccess,
        recipientName: recipientName,
        amount: amount,
        reference: reference,
        narration: narration,
        senderName: senderName,
        errorMessage: errorMessage,
        onDone: onDone,
        onRetry: onRetry,
      ),
    );
  }

  void _copyReference(BuildContext context, String refCode) {
    Clipboard.setData(ClipboardData(text: refCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Transaction reference copied!'),
        backgroundColor: AppColors.income,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final refCode = reference ?? 'PF-TRF-${DateTime.now().millisecondsSinceEpoch}';

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Back',
                ),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: AppDimensions.spaceLg),

            if (isSuccess) ...[
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
                        size: AppDimensions.iconLg + 4,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spaceMd),
                    Text(
                      'Transfer Successful!',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.income,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spaceXs),
                    Text(
                      '₦${amount.toStringAsFixed(2)}',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sent to $recipientName',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.spaceLg),

              PayFlowCard(
                padding: const EdgeInsets.all(AppDimensions.spaceLg),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Transaction Type',
                          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                        ),
                        Text(
                          'Money Transfer',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: AppDimensions.spaceLg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Narration',
                          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                        ),
                        Flexible(
                          child: Text(
                            (narration != null && narration!.trim().isNotEmpty)
                                ? narration!.trim()
                                : 'None',
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: AppDimensions.spaceLg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Transaction Reference',
                          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                        ),
                        Flexible(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Flexible(
                                child: Text(
                                  refCode,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => _copyReference(context, refCode),
                                child: const Icon(
                                  Icons.copy_rounded,
                                  color: AppColors.primary,
                                  size: AppDimensions.iconSm - 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: AppDimensions.spaceLg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Status',
                          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                        ),
                        const Text(
                          'Completed',
                          style: TextStyle(
                            color: AppColors.income,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.spaceXl),

              Row(
                children: [
                  Expanded(
                    child: PayFlowButton(
                      text: 'View Receipt',
                      variant: PayFlowButtonVariant.outline,
                      onPressed: () {
                        Navigator.of(context).pop();
                        TransactionDetailSheet.show(
                          context,
                          TransactionItem(
                            id: 'tx_transfer_${DateTime.now().millisecondsSinceEpoch}',
                            title: 'Transfer to $recipientName',
                            category: 'Transfer',
                            amount: amount,
                            timestamp: DateTime.now(),
                            isCredit: false,
                            status: 'Completed',
                            reference: refCode,
                            recipientOrSender: recipientName,
                            recipientName: recipientName,
                            senderName: senderName ?? 'You',
                            transferType: 'Money Transfer',
                            narration: (narration != null && narration!.trim().isNotEmpty) ? narration!.trim() : null,
                            description: (narration != null && narration!.trim().isNotEmpty) ? narration!.trim() : null,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spaceMd),
                  Expanded(
                    child: PayFlowButton(
                      text: 'Done',
                      onPressed: () {
                        Navigator.of(context).pop();
                        if (onDone != null) onDone!();
                      },
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Failure View
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.spaceLg),
                      decoration: const BoxDecoration(
                        color: AppColors.expense,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: AppDimensions.iconLg + 4,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spaceMd),
                    Text(
                      'Transfer Failed',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.expense,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spaceSm),
                    Text(
                      errorMessage ?? 'An error occurred during transfer processing.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.spaceXl),

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
                      text: 'Retry',
                      onPressed: () {
                        Navigator.of(context).pop();
                        if (onRetry != null) onRetry!();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
