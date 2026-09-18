import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/payflow_card.dart';
import '../../auth/view_models/auth_view_model.dart';
import '../models/transaction_item.dart';
import '../../wallet/view_models/wallet_view_model.dart';
import '../../wallet/widgets/transaction_detail_sheet.dart';

class TransactionHistoryCard extends ConsumerWidget {
  final List<TransactionItem>? transactions;

  const TransactionHistoryCard({
    super.key,
    this.transactions,
  });

  String _formatDate(DateTime dt) {
    return 'Today, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authViewModelProvider);
    final currentUserId = authState.phoneNumber ?? '';
    final walletState = ref.watch(walletViewModelProvider);
    final items = transactions ?? walletState.recentTransactions;

    return PayFlowCard(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Transactions',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              GestureDetector(
                onTap: () => context.go('/wallet'),
                child: Text(
                  'See All',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceMd),
          if (items.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppDimensions.spaceSm),
              child: Text(
                'No recent transactions',
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
              ),
            ),
          ] else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: AppDimensions.spaceMd),
              itemBuilder: (context, index) {
                final tx = items[index];
                final isCredit = tx.isCredit;
                final amountText =
                    '${isCredit ? '+' : '-'}₦${tx.amount.toStringAsFixed(2)}';

                return InkWell(
                  onTap: () => TransactionDetailSheet.show(context, tx),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppDimensions.spaceSm),
                          decoration: BoxDecoration(
                            color: (isCredit ? AppColors.income : AppColors.expense)
                                .withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isCredit
                                ? Icons.arrow_downward_rounded
                                : Icons.arrow_upward_rounded,
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
                                getTransactionTitle(tx, currentUserId),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                _formatDate(tx.timestamp),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontSize: 11,
                                  color: theme.textTheme.bodyMedium?.color
                                      ?.withValues(alpha: 0.6),
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
                              tx.status,
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
              },
            ),
          ],
        ],
      ),
    );
  }
}
