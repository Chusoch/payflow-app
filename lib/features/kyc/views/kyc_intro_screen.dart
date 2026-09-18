import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/payflow_badge.dart';
import '../../../core/widgets/payflow_button.dart';
import '../../../core/widgets/payflow_card.dart';
import '../models/kyc_tier.dart';
import '../view_models/kyc_view_model.dart';

class KycIntroScreen extends ConsumerWidget {
  const KycIntroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final kycState = ref.watch(kycViewModelProvider);

    final currentTierInfo = KycTierInfo.getTierInfo(kycState.tierLevel);

    return Scaffold(
      appBar: AppBar(
        title: const Text('KYC Verification'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.spaceMd),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - AppDimensions.spaceMd * 2),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Current Tier Status Header
                      PayFlowCard(
                        variant: PayFlowCardVariant.gradient,
                        padding: const EdgeInsets.all(AppDimensions.spaceLg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Current Verification Tier',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                PayFlowBadge(
                                  label: kycState.status == KycStatus.verified
                                      ? 'VERIFIED'
                                      : kycState.status == KycStatus.inProgress
                                          ? 'IN PROGRESS'
                                          : 'TIER 1 BASIC',
                                  status: kycState.status == KycStatus.verified
                                      ? PayFlowBadgeStatus.success
                                      : PayFlowBadgeStatus.warning,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppDimensions.spaceSm),
                            Text(
                              currentTierInfo.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Daily Limit: ₦${currentTierInfo.dailyLimit.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spaceLg),

                      Text(
                        'Account Verification Tiers',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spaceSm),

                      // List of Tiers (Tier 1, Tier 2, Tier 3)
                      _TierCard(
                        tierInfo: KycTierInfo.getTierInfo(KycTierLevel.tier1),
                        isCurrent: kycState.tierLevel == KycTierLevel.tier1,
                      ),
                      const SizedBox(height: AppDimensions.spaceSm),
                      _TierCard(
                        tierInfo: KycTierInfo.getTierInfo(KycTierLevel.tier2),
                        isCurrent: kycState.tierLevel == KycTierLevel.tier2,
                      ),
                      const SizedBox(height: AppDimensions.spaceSm),
                      _TierCard(
                        tierInfo: KycTierInfo.getTierInfo(KycTierLevel.tier3),
                        isCurrent: kycState.tierLevel == KycTierLevel.tier3,
                      ),

                      const Spacer(),
                      const SizedBox(height: AppDimensions.spaceLg),

                      // Action Button
                      if (kycState.status == KycStatus.verified && kycState.tierLevel == KycTierLevel.tier3) ...[
                        PayFlowButton(
                          text: 'View KYC Status',
                          onPressed: () => context.push('/kyc/status'),
                        ),
                      ] else ...[
                        PayFlowButton(
                          text: kycState.status == KycStatus.inProgress
                              ? 'Continue Verification'
                              : 'Upgrade Verification Tier',
                          onPressed: () {
                            ref.read(kycViewModelProvider.notifier).setAccountType(AccountType.individual);
                            context.push('/kyc/personal-info');
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.tierInfo,
    required this.isCurrent,
  });

  final KycTierInfo tierInfo;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PayFlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tierInfo.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isCurrent)
                const PayFlowBadge(
                  label: 'ACTIVE TIER',
                  status: PayFlowBadgeStatus.info,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            tierInfo.subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
          ),
          const SizedBox(height: AppDimensions.spaceSm),
          Row(
            children: [
              const Icon(Icons.currency_exchange_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Daily Limit: ₦${tierInfo.dailyLimit.toStringAsFixed(0)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const Divider(height: AppDimensions.spaceLg),
          ...tierInfo.requirements.map(
            (req) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 16, color: AppColors.income),
                  const SizedBox(width: 8),
                  Text(
                    req,
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
