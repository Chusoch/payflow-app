import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/payflow_card.dart';
import '../../auth/view_models/auth_view_model.dart';
import '../../kyc/models/kyc_tier.dart';
import '../../kyc/view_models/kyc_view_model.dart';
import '../../notifications/view_models/notification_view_model.dart';
import '../../profile/view_models/profile_view_model.dart';
import '../../transfer/view_models/transfer_view_model.dart';
import '../../wallet/view_models/wallet_view_model.dart';
import '../../wallet/widgets/fund_wallet_sheet.dart';
import '../view_models/home_view_model.dart';
import '../widgets/promo_banner_carousel.dart';
import '../widgets/quick_actions_section.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(walletViewModelProvider.notifier).refreshWallet();
      ref.read(walletViewModelProvider.notifier).getTransactions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileState = ref.watch(profileViewModelProvider);
    final walletState = ref.watch(walletViewModelProvider);
    final balance = walletState.balance;
    final transactions = walletState.recentTransactions;
    final homeState = ref.watch(homeViewModelProvider);
    final homeNotifier = ref.read(homeViewModelProvider.notifier);
    final kycState = ref.watch(kycViewModelProvider);
    final authState = ref.watch(authViewModelProvider);
    final notificationState = ref.watch(notificationViewModelProvider);
    final unreadCount = notificationState.unreadCount;

    final user = authState.user;
    final String firstName;
    if (user?.firstName?.trim().isNotEmpty == true) {
      firstName = user!.firstName!.trim();
    } else if (user?.fullName?.trim().isNotEmpty == true) {
      firstName = user!.fullName!.trim().split(' ').first;
    } else if (authState.fullName?.trim().isNotEmpty == true) {
      firstName = authState.fullName!.trim().split(' ').first;
    } else if (profileState.fullName.trim().isNotEmpty) {
      firstName = profileState.fullName.trim().split(' ').first;
    } else if (homeState.userName.isNotEmpty &&
        !homeState.userName.startsWith('User +') &&
        !homeState.userName.startsWith('User 0')) {
      firstName = homeState.userName.trim().split(' ').first;
    } else {
      firstName = 'User';
    }

    return Scaffold(
      body: SafeArea(
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 350),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, (1 - value) * 12),
                child: child,
              ),
            );
          },
          child: RefreshIndicator(
            onRefresh: () async {
              await Future.wait([
                homeNotifier.refresh(),
                ref.read(walletViewModelProvider.notifier).refreshWallet(),
              ]);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spaceMd,
                vertical: AppDimensions.spaceSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Home Top Header: Avatar + "Hi, $firstName" + Bell with Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                              child: Text(
                                firstName.isNotEmpty ? firstName.substring(0, 1).toUpperCase() : 'U',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppDimensions.spaceSm + 4),
                            Expanded(
                              child: Text(
                                'Hi, $firstName',
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Badge(
                        isLabelVisible: unreadCount > 0,
                        label: Text('$unreadCount', style: const TextStyle(fontSize: 10)),
                        child: IconButton(
                          onPressed: () {
                            context.push('/notifications');
                          },
                          icon: const Icon(Icons.notifications_none_rounded, size: 22),
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                            backgroundColor: theme.brightness == Brightness.dark
                                ? AppColors.surfaceVariantDark
                                : AppColors.surfaceVariantLight,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // KYC Verification Prompt Banner
                  if (kycState.status != KycStatus.verified ||
                      kycState.tierLevel != KycTierLevel.tier3) ...[
                    const SizedBox(height: AppDimensions.spaceSm + 4),
                    PayFlowCard(
                      variant: PayFlowCardVariant.outlined,
                      onTap: () => context.push('/kyc/intro'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.spaceMd,
                        vertical: AppDimensions.spaceSm + 2,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppDimensions.spaceSm),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.verified_user_outlined,
                              color: AppColors.primary,
                              size: AppDimensions.iconSm + 2,
                            ),
                          ),
                          const SizedBox(width: AppDimensions.spaceMd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  kycState.status == KycStatus.inProgress
                                      ? 'Complete Verification'
                                      : 'Upgrade Account Limit',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  'Verify BVN & NIN for higher daily limits.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.primary,
                            size: AppDimensions.iconSm + 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppDimensions.spaceSm + 4),

                  // 1. Balance Card (Hero Element with Eye Toggle and + Add Money Button)
                  PayFlowCard(
                    variant: PayFlowCardVariant.gradient,
                    padding: const EdgeInsets.all(AppDimensions.spaceLg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Main Wallet Balance',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: AppDimensions.spaceSm),
                                GestureDetector(
                                  onTap: homeNotifier.toggleBalanceVisibility,
                                  child: Icon(
                                    homeState.isBalanceVisible
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: Colors.white70,
                                    size: AppDimensions.iconSm,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppDimensions.spaceSm + 2,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius:
                                    BorderRadius.circular(AppDimensions.radiusFull),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.account_balance_outlined,
                                    color: Colors.white,
                                    size: 13,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Acc: ${homeState.accountNumber.isNotEmpty ? homeState.accountNumber : '--'}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.spaceMd),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  homeState.isBalanceVisible
                                      ? '₦${balance.toStringAsFixed(2)}'
                                      : '₦ • • • • • • •',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppDimensions.spaceMd),
                            GestureDetector(
                              key: const Key('add_money_button'),
                              onTap: () => FundWalletSheet.show(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add_rounded, size: 18, color: AppColors.primary),
                                    SizedBox(width: 4),
                                    Text(
                                      'Add Money',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spaceSm + 2),

                  // 2. Top Transaction Ticker (Compact Clickable Pill)
                  _TransactionTicker(
                    transaction: transactions.isNotEmpty ? transactions.first : null,
                    onTap: () => context.go('/wallet'),
                  ),
                  const SizedBox(height: AppDimensions.spaceMd),

                  // 3. Primary Transfer Actions Row (To PayFlow, To Bank, Add Money)
                  PayFlowCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spaceMd,
                      vertical: AppDimensions.spaceMd,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _TransferActionItem(
                          icon: Icons.swap_horiz_rounded,
                          label: 'To PayFlow',
                          color: AppColors.primary,
                          onTap: () {
                            ref.read(transferViewModelProvider.notifier).setTransferType('PayFlow User');
                            context.go('/transfer');
                          },
                        ),
                        _TransferActionItem(
                          icon: Icons.account_balance_rounded,
                          label: 'To Bank',
                          color: const Color(0xFF00BFA5),
                          onTap: () {
                            ref.read(transferViewModelProvider.notifier).setTransferType('Bank Account');
                            context.go('/transfer');
                          },
                        ),
                        _TransferActionItem(
                          key: const Key('primary_add_money_button'),
                          icon: Icons.add_card_rounded,
                          label: 'Add Money',
                          color: const Color(0xFFFF9100),
                          onTap: () => FundWalletSheet.show(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spaceMd),

                  // 4. Services Grid (Airtime, Mobile Data, Electricity, Cable TV)
                  const QuickActionsSection(),
                  const SizedBox(height: AppDimensions.spaceMd),

                  // 5. Promotional Banner Carousel
                  if (homeState.promoBanners.isNotEmpty) ...[
                    PromoBannerCarousel(
                      banners: homeState.promoBanners,
                      currentIndex: homeState.currentBannerIndex,
                      onPageChanged: homeNotifier.setBannerIndex,
                    ),
                    const SizedBox(height: AppDimensions.spaceMd),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TransactionTicker extends StatelessWidget {
  final TransactionItem? transaction;
  final VoidCallback onTap;

  const _TransactionTicker({
    required this.transaction,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tx = transaction;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? AppColors.surfaceVariantDark
              : AppColors.surfaceVariantLight,
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          border: Border.all(
            color: theme.dividerColor.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            if (tx != null) ...[
              Icon(
                tx.isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                size: 16,
                color: tx.isCredit ? AppColors.income : AppColors.expense,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${tx.getFormattedTitle()} ₦${tx.amount.toStringAsFixed(2)}',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ] else ...[
              const Icon(
                Icons.swap_horiz_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No recent transactions',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
            const SizedBox(width: 8),
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Transactions',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TransferActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _TransferActionItem({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spaceSm,
          vertical: AppDimensions.spaceXs,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppDimensions.spaceSm + 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: AppDimensions.iconMd,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
