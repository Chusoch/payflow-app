import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/payflow_card.dart';
import '../view_models/wallet_view_model.dart';
import '../widgets/fund_wallet_sheet.dart';
import '../widgets/statement_export_sheet.dart';
import '../widgets/transaction_detail_sheet.dart';
import '../../auth/view_models/auth_view_model.dart';
import '../../home/models/transaction_item.dart';
import '../../profile/view_models/profile_view_model.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} • ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authViewModelProvider);
    final currentUserId = authState.phoneNumber ?? '';
    final walletState = ref.watch(walletViewModelProvider);
    final walletNotifier = ref.read(walletViewModelProvider.notifier);
    final profileState = ref.watch(profileViewModelProvider);
    final accNum = profileState.accountNumber.isNotEmpty ? profileState.accountNumber : '--';
    final transactions = walletState.filteredTransactions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wallet'),
        actions: [
          IconButton(
            onPressed: () => FundWalletSheet.show(context),
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Fund Wallet',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => walletNotifier.refreshWallet(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Balance Card & Account Information
              PayFlowCard(
                variant: PayFlowCardVariant.gradient,
                padding: const EdgeInsets.all(AppDimensions.spaceLg),
                gradient: AppColors.primaryGradient,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(
                          child: Text(
                            'Main Wallet Balance',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppDimensions.spaceSm),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimensions.spaceSm,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius:
                                  BorderRadius.circular(AppDimensions.radiusSm),
                            ),
                            child: Text(
                              'Acc: $accNum',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spaceSm),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '₦${walletState.mainBalance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spaceLg),

                    // Primary Wallet Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            label: 'Fund Wallet',
                            icon: Icons.add_rounded,
                            onTap: () => FundWalletSheet.show(context),
                          ),
                        ),
                        const SizedBox(width: AppDimensions.spaceMd),
                        Expanded(
                          child: _ActionButton(
                            label: 'Send Money',
                            icon: Icons.send_rounded,
                            onTap: () => context.go('/transfer'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.spaceLg),

              // Transaction History Section (Dedicated on Wallet Screen)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Transaction History',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => StatementExportSheet.show(context),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                    label: const Text('Statement'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spaceSm),

              // Transaction Filter Tabs (All, Money In, Money Out)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', 'Money In', 'Money Out'].map((filter) {
                    final isSelected = walletState.activeFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: AppDimensions.spaceSm),
                      child: ChoiceChip(
                        label: Text(filter),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            walletNotifier.setTransactionFilter(filter);
                          }
                        },
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: AppDimensions.spaceSm),

              // Transaction History List
              PayFlowCard(
                padding: const EdgeInsets.all(AppDimensions.spaceMd),
                child: transactions.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: AppDimensions.spaceLg),
                        child: Center(
                          child: Text(
                            walletState.activeFilter == 'All'
                                ? 'No transactions yet.'
                                : 'No transactions found for "${walletState.activeFilter}".',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: transactions.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: AppDimensions.spaceMd),
                        itemBuilder: (context, index) {
                          final tx = transactions[index];
                          final isCredit = tx.isCredit;
                          final amountText =
                              '${isCredit ? '+' : '-'}₦${tx.amount.toStringAsFixed(2)}';

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            onTap: () => TransactionDetailSheet.show(context, tx),
                            leading: Container(
                              padding: const EdgeInsets.all(AppDimensions.spaceSm),
                              decoration: BoxDecoration(
                                color: (isCredit
                                        ? AppColors.income
                                        : AppColors.expense)
                                    .withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isCredit
                                    ? Icons.arrow_downward_rounded
                                    : Icons.arrow_upward_rounded,
                                color: isCredit
                                    ? AppColors.income
                                    : AppColors.expense,
                                size: AppDimensions.iconSm + 2,
                              ),
                            ),
                            title: Text(
                              getTransactionTitle(tx, currentUserId),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              _formatDate(tx.timestamp),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 11,
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  amountText,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isCredit
                                        ? AppColors.income
                                        : AppColors.expense,
                                  ),
                                ),
                                Text(
                                  tx.status,
                                  style: const TextStyle(
                                    color: AppColors.income,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppDimensions.spaceSm + 2,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: AppDimensions.iconSm + 2),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

