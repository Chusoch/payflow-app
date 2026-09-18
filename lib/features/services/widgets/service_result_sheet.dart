import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/payflow_button.dart';
import '../../../core/widgets/payflow_card.dart';
import '../../../core/services/pdf_generator_service.dart';
import '../../home/models/transaction_item.dart';

class ServiceResultSheet extends StatelessWidget {
  final bool isSuccess;
  final String serviceTitle;
  final String providerName;
  final String identifier;
  final double amount;
  final String? reference;
  final String? token;
  final String? errorMessage;
  final VoidCallback? onDone;
  final VoidCallback? onRetry;

  const ServiceResultSheet({
    super.key,
    required this.isSuccess,
    required this.serviceTitle,
    required this.providerName,
    required this.identifier,
    required this.amount,
    this.reference,
    this.token,
    this.errorMessage,
    this.onDone,
    this.onRetry,
  });

  static Future<void> show({
    required BuildContext context,
    required bool isSuccess,
    required String serviceTitle,
    required String providerName,
    required String identifier,
    required double amount,
    String? reference,
    String? token,
    String? errorMessage,
    VoidCallback? onDone,
    VoidCallback? onRetry,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ServiceResultSheet(
        isSuccess: isSuccess,
        serviceTitle: serviceTitle,
        providerName: providerName,
        identifier: identifier,
        amount: amount,
        reference: reference,
        token: token,
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

  void _copyToken(BuildContext context, String tokenStr) {
    Clipboard.setData(ClipboardData(text: tokenStr));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Electricity token copied to clipboard!'),
        backgroundColor: AppColors.income,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _downloadReceipt(BuildContext context, String refCode) async {
    final item = TransactionItem(
      id: refCode,
      title: serviceTitle,
      category: providerName,
      amount: amount,
      timestamp: DateTime.now(),
      isCredit: false,
      status: 'Completed',
      reference: refCode,
      recipientOrSender: identifier,
      token: token,
    );
    try {
      final path = await PdfGeneratorService.downloadReceiptPdf(item);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(kIsWeb
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

  void _shareReceipt(BuildContext context, String refCode) {
    final item = TransactionItem(
      id: refCode,
      title: serviceTitle,
      category: providerName,
      amount: amount,
      timestamp: DateTime.now(),
      isCredit: false,
      status: 'Completed',
      reference: refCode,
      recipientOrSender: identifier,
      token: token,
    );
    if (kIsWeb) {
      final summary = PdfGeneratorService.formatReceiptSummary(item);
      Clipboard.setData(ClipboardData(text: summary));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt details copied to clipboard!'),
        ),
      );
      return;
    }
    PdfGeneratorService.shareReceiptPdf(item, context: context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final refCode = reference ?? 'PF-SVC-${DateTime.now().millisecondsSinceEpoch}';

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
                const SizedBox(width: 32),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Close',
                  onPressed: () {
                    Navigator.of(context).pop();
                    if (onDone != null) onDone!();
                  },
                ),
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
                      'Payment Successful!',
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
                      '$serviceTitle • $providerName',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.spaceLg),

              if (token != null) ...[
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
                            onTap: () => _copyToken(context, token!),
                            child: const Row(
                              children: [
                                Icon(Icons.copy_rounded, color: AppColors.primary, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Copy',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        token!,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceLg),
              ],

              PayFlowCard(
                padding: const EdgeInsets.all(AppDimensions.spaceLg),
                child: Column(
                  children: [
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
                          'Account / Number',
                          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                        ),
                        const SizedBox(width: AppDimensions.spaceSm),
                        Flexible(
                          child: Text(
                            identifier,
                            textAlign: TextAlign.end,
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
              const SizedBox(height: AppDimensions.spaceLg),

              // Share & Download Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _shareReceipt(context, refCode),
                      icon: const Icon(Icons.share_outlined, size: 16),
                      label: const Text('Share'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spaceMd),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _downloadReceipt(context, refCode),
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Download PDF'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spaceLg),

              PayFlowButton(
                text: 'Done',
                onPressed: () {
                  Navigator.of(context).pop();
                  if (onDone != null) onDone!();
                },
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
                      'Payment Failed',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.expense,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spaceSm),
                    Text(
                      errorMessage ?? 'An error occurred during payment processing.',
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
