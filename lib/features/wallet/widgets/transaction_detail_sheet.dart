import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/payflow_button.dart';
import '../../../core/widgets/payflow_card.dart';
import '../../../core/services/pdf_generator_service.dart';
import '../../home/models/transaction_item.dart';

class TransactionDetailSheet extends StatelessWidget {
  final TransactionItem transaction;
  final bool isWeb;

  const TransactionDetailSheet({
    super.key,
    required this.transaction,
    this.isWeb = kIsWeb,
  });

  static Future<void> show(BuildContext context, TransactionItem transaction, {bool isWeb = kIsWeb}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TransactionDetailSheet(transaction: transaction, isWeb: isWeb),
    );
  }

  String _formatDateTime(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _copyText(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        backgroundColor: AppColors.income,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _downloadReceipt(BuildContext context) async {
    try {
      final path = await PdfGeneratorService.downloadReceiptPdf(transaction, isWebOverride: isWeb);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isWeb
                ? 'Receipt downloaded: ${path.split('/').last}'
                : 'Receipt downloaded & saved: ${path.split('/').last}'),
            backgroundColor: AppColors.income,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download receipt: $e'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    }
  }

  void _shareReceipt(BuildContext context) {
    if (isWeb) {
      final summary = PdfGeneratorService.formatReceiptSummary(transaction);
      Clipboard.setData(ClipboardData(text: summary));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt details copied to clipboard!'),
        ),
      );
      return;
    }
    PdfGeneratorService.shareReceiptPdf(transaction, context: context, isWebOverride: isWeb);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCredit = transaction.isCredit;
    final amountColor = isCredit ? AppColors.income : AppColors.expense;
    final refCode = transaction.reference ?? 'PF-TXN-${transaction.id}';

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
            const SizedBox(height: AppDimensions.spaceMd),

            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.spaceMd),
                    decoration: BoxDecoration(
                      color: amountColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCredit
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                      color: amountColor,
                      size: AppDimensions.iconLg,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spaceSm),
                  Text(
                    '${isCredit ? '+' : '-'}₦${transaction.amount.toStringAsFixed(2)}',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: amountColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    transaction.getFormattedTitle(),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spaceXs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spaceSm + 2,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.income.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    ),
                    child: Text(
                      transaction.status,
                      style: const TextStyle(
                        color: AppColors.income,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spaceLg),

            // Electricity Token Highlight Card
            if (transaction.token != null) ...[
              PayFlowCard(
                variant: PayFlowCardVariant.outlined,
                padding: const EdgeInsets.all(AppDimensions.spaceMd),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.bolt_rounded, color: AppColors.pending, size: 20),
                            SizedBox(width: 6),
                            Text(
                              'Electricity Token',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () => _copyText(context, transaction.token!, 'Electricity token'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.copy_rounded, color: Colors.white, size: 12),
                                SizedBox(width: 4),
                                Text(
                                  'Copy',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      transaction.token!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.spaceMd),
            ],

            // Transaction Info Table
            PayFlowCard(
              padding: const EdgeInsets.all(AppDimensions.spaceLg),
              child: Column(
                children: [
                  _InfoRow(
                    label: 'Date & Time',
                    value: _formatDateTime(transaction.timestamp),
                  ),
                  const Divider(height: AppDimensions.spaceLg),
                  _InfoRow(
                    label: 'Category',
                    value: transaction.category,
                  ),
                  const Divider(height: AppDimensions.spaceLg),
                  _InfoRow(
                    label: 'Transaction Type',
                    value: transaction.transferType ?? (isCredit ? 'Credit Transfer' : 'Debit Payment'),
                  ),
                  const Divider(height: AppDimensions.spaceLg),
                  _InfoRow(
                    label: 'Narration',
                    value: (transaction.narration != null && transaction.narration!.trim().isNotEmpty)
                        ? transaction.narration!.trim()
                        : ((transaction.description != null && transaction.description!.trim().isNotEmpty)
                            ? transaction.description!.trim()
                            : 'None'),
                  ),
                  if (transaction.senderName != null && transaction.senderName!.trim().isNotEmpty) ...[
                    const Divider(height: AppDimensions.spaceLg),
                    _InfoRow(
                      label: 'Sender',
                      value: transaction.senderName!.trim(),
                    ),
                  ] else if (isCredit && transaction.recipientOrSender != null && transaction.recipientOrSender!.trim().isNotEmpty) ...[
                    const Divider(height: AppDimensions.spaceLg),
                    _InfoRow(
                      label: 'Sender',
                      value: transaction.recipientOrSender!.trim(),
                    ),
                  ],
                  if (transaction.recipientName != null && transaction.recipientName!.trim().isNotEmpty) ...[
                    const Divider(height: AppDimensions.spaceLg),
                    _InfoRow(
                      label: 'Recipient',
                      value: transaction.recipientName!.trim(),
                    ),
                  ] else if (!isCredit && transaction.recipientOrSender != null && transaction.recipientOrSender!.trim().isNotEmpty) ...[
                    const Divider(height: AppDimensions.spaceLg),
                    _InfoRow(
                      label: 'Recipient',
                      value: transaction.recipientOrSender!.trim(),
                    ),
                  ],
                  const Divider(height: AppDimensions.spaceLg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Transaction Reference',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          color: theme.textTheme.bodyMedium?.color
                              ?.withValues(alpha: 0.7),
                        ),
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
                              onTap: () => _copyText(context, refCode, 'Transaction reference'),
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
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spaceLg),

            // Share & Download Receipt Action Buttons
            Row(
              children: [
                Expanded(
                  child: PayFlowButton(
                    text: 'Share',
                    icon: const Icon(Icons.share_rounded, size: 18),
                    variant: PayFlowButtonVariant.outline,
                    onPressed: () => _shareReceipt(context),
                  ),
                ),
                const SizedBox(width: AppDimensions.spaceMd),
                Expanded(
                  child: PayFlowButton(
                    text: 'Download PDF',
                    icon: const Icon(Icons.download_rounded, size: 18),
                    onPressed: () => _downloadReceipt(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spaceSm),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
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
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
