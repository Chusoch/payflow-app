import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/env.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/payflow_badge.dart';
import '../../../core/widgets/payflow_button.dart';
import '../../../core/widgets/payflow_card.dart';
import '../../../core/widgets/payflow_text_field.dart';
import '../view_models/kyc_view_model.dart';

class KycIdentityScreen extends ConsumerStatefulWidget {
  const KycIdentityScreen({super.key});

  @override
  ConsumerState<KycIdentityScreen> createState() => _KycIdentityScreenState();
}

class _KycIdentityScreenState extends ConsumerState<KycIdentityScreen> {
  late TextEditingController _bvnController;
  late TextEditingController _ninController;

  @override
  void initState() {
    super.initState();
    final kycState = ref.read(kycViewModelProvider);
    _bvnController = TextEditingController(
      text: kycState.bvn.isNotEmpty
          ? kycState.bvn
          : (Env.isMockMode ? '22345678901' : ''),
    );
    _ninController = TextEditingController(
      text: kycState.nin.isNotEmpty
          ? kycState.nin
          : (Env.isMockMode ? '12345678901' : ''),
    );
  }

  @override
  void dispose() {
    _bvnController.dispose();
    _ninController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kycState = ref.watch(kycViewModelProvider);
    final kycNotifier = ref.read(kycViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Identity Verification'),
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
                      Text(
                        'BVN & NIN Verification',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spaceXs),
                      Text(
                        'We are required by financial regulations to verify your identity before enabling higher account limits.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppDimensions.spaceLg),

                      // Security Info Banner Card
                      PayFlowCard(
                        variant: PayFlowCardVariant.outlined,
                        child: Row(
                          children: [
                            const Icon(Icons.shield_outlined, color: AppColors.primary, size: 28),
                            const SizedBox(width: AppDimensions.spaceMd),
                            Expanded(
                              child: Text(
                                'Your BVN and NIN do not give access to your bank accounts. They are only used to confirm your identity.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spaceLg),

                      // BVN Input & Verification Section
                      PayFlowCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Bank Verification Number (BVN)',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                PayFlowBadge(
                                  label: kycState.isBvnVerified ? 'VERIFIED' : 'UNVERIFIED',
                                  status: kycState.isBvnVerified
                                      ? PayFlowBadgeStatus.success
                                      : PayFlowBadgeStatus.warning,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppDimensions.spaceSm),

                            PayFlowTextField(
                              hintText: '11-digit BVN',
                              keyboardType: TextInputType.number,
                              controller: _bvnController,
                              errorText: kycState.bvnError,
                              suffixIcon: kycState.isBvnVerified
                                  ? const Icon(Icons.check_circle_rounded, color: AppColors.income)
                                  : null,
                            ),
                            const SizedBox(height: AppDimensions.spaceMd),

                            PayFlowButton(
                              text: kycState.isBvnVerified ? 'Re-verify BVN' : 'Verify BVN',
                              variant: kycState.isBvnVerified
                                  ? PayFlowButtonVariant.outline
                                  : PayFlowButtonVariant.primary,
                              isLoading: kycState.isLoading && !kycState.isNinVerified,
                              onPressed: () {
                                kycNotifier.verifyBvn(_bvnController.text);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spaceLg),

                      // NIN Input & Verification Section
                      PayFlowCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'National Identity Number (NIN)',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                PayFlowBadge(
                                  label: kycState.isNinVerified ? 'VERIFIED' : 'UNVERIFIED',
                                  status: kycState.isNinVerified
                                      ? PayFlowBadgeStatus.success
                                      : PayFlowBadgeStatus.warning,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppDimensions.spaceSm),

                            PayFlowTextField(
                              hintText: '11-digit NIN',
                              keyboardType: TextInputType.number,
                              controller: _ninController,
                              errorText: kycState.ninError,
                              suffixIcon: kycState.isNinVerified
                                  ? const Icon(Icons.check_circle_rounded, color: AppColors.income)
                                  : null,
                            ),
                            const SizedBox(height: AppDimensions.spaceMd),

                            PayFlowButton(
                              text: kycState.isNinVerified ? 'Re-verify NIN' : 'Verify NIN',
                              variant: kycState.isNinVerified
                                  ? PayFlowButtonVariant.outline
                                  : PayFlowButtonVariant.primary,
                              isLoading: kycState.isLoading && kycState.isBvnVerified,
                              onPressed: () {
                                kycNotifier.verifyNin(_ninController.text);
                              },
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),
                      const SizedBox(height: AppDimensions.spaceLg),

                      PayFlowButton(
                        text: 'Continue to Liveness Check',
                        onPressed: () {
                          if (!kycState.isBvnVerified || !kycState.isNinVerified) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please verify both your BVN and NIN to continue.'),
                                backgroundColor: AppColors.expense,
                              ),
                            );
                            return;
                          }
                          context.push('/kyc/liveness');
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
