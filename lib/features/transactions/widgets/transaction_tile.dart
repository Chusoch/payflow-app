import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/view_models/auth_view_model.dart';
import '../../home/models/transaction_item.dart';
import '../../wallet/widgets/transaction_detail_sheet.dart';

class TransactionTile extends ConsumerWidget {
  final TransactionItem transaction;
  final String? currentUserId;
  final VoidCallback? onTap;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.currentUserId,
    this.onTap,
  });

  String _formatDate(DateTime dt) {
    return 'Today, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isCredit = transaction.isCredit;
    final amountText = '${isCredit ? '+' : '-'}₦${transaction.amount.toStringAsFixed(2)}';

    // Determine current user ID / phone number for directional narrative resolution
    final activeUserId = currentUserId ?? ref.watch(authViewModelProvider).phoneNumber ?? '';
    final titleText = getTransactionTitle(transaction, activeUserId);

    return InkWell(
      onTap: onTap ?? () => TransactionDetailSheet.show(context, transaction),
      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppDimensions.spaceSm),
              decoration: BoxDecoration(
                color: (isCredit ? AppColors.income : AppColors.expense).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                color: isCredit ? AppColors.income : AppColors.expense,
                size: AppDimensions.iconSm + 2,
              ),
            ),
            const SizedBox(width: AppDimensions.spaceSm + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    _formatDate(transaction.timestamp),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 11,
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimensions.spaceSm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amountText,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isCredit ? AppColors.income : AppColors.expense,
                  ),
                ),
                Text(
                  transaction.status,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 10,
                    color: AppColors.income,
                    fontWeight: FontWeight.w500,
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
