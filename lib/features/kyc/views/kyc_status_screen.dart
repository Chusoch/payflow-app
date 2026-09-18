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

class KycStatusScreen extends ConsumerWidget {
  const KycStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final kycState = ref.watch(kycViewModelProvider);

    final tierInfo = KycTierInfo.getTierInfo(kycState.tierLevel);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification Status'),
        automaticallyImplyLeading: false,
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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: AppDimensions.spaceLg),

                      // Verification Celebration Icon
                      Container(
                        padding: const EdgeInsets.all(AppDimensions.spaceLg),
                        decoration: BoxDecoration(
                          color: AppColors.income.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          color: AppColors.income,
                          size: 64,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spaceMd),

                      Text(
                        'KYC Verification Complete!',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppDimensions.spaceXs),
                      Text(
                        'Your identity documents have been processed and verified successfully.',
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppDimensions.spaceLg),

                      // Tier Status & Limits Card
                      PayFlowCard(
                        variant: PayFlowCardVariant.gradient,
                        padding: const EdgeInsets.all(AppDimensions.spaceLg),
                        child: Column(
                          children: [
                            const PayFlowBadge(
                              label: 'VERIFIED ACCOUNT',
                              status: PayFlowBadgeStatus.success,
                            ),
                            const SizedBox(height: AppDimensions.spaceMd),
                            Text(
                              tierInfo.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tierInfo.subtitle,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const Divider(height: AppDimensions.spaceLg, color: Colors.white30),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    const Text(
                                      'Daily Transfer Limit',
                                      style: TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₦${tierInfo.dailyLimit.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(height: 30, width: 1, color: Colors.white30),
                                Column(
                                  children: [
                                    const Text(
                                      'Single Tx Limit',
                                      style: TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₦${tierInfo.singleTransactionLimit.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spaceLg),

                      // Unlocked Capabilities Card
                      PayFlowCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Unlocked Capabilities',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: AppDimensions.spaceMd),
                            const _FeatureCheckRow(text: 'Higher Daily Transfer & Payment Limits'),
                            const SizedBox(height: AppDimensions.spaceSm),
                            const _FeatureCheckRow(text: 'Instant Bank Transfers & Bill Vending'),
                            const SizedBox(height: AppDimensions.spaceSm),
                            const _FeatureCheckRow(text: 'Priority Customer Support & Security Guards'),
                          ],
                        ),
                      ),

                      const Spacer(),
                      const SizedBox(height: AppDimensions.spaceLg),

                      PayFlowButton(
                        text: 'Return to Home Dashboard',
                        onPressed: () {
                          context.go('/home');
                        },
                      ),
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

class _FeatureCheckRow extends StatelessWidget {
  const _FeatureCheckRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        const Icon(Icons.check_circle_rounded, color: AppColors.income, size: 20),
        const SizedBox(width: AppDimensions.spaceSm + 2),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
