import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/payflow_badge.dart';
import '../../../core/widgets/payflow_button.dart';
import '../../../core/widgets/payflow_card.dart';
import '../view_models/kyc_view_model.dart';

class KycLivenessScreen extends ConsumerWidget {
  const KycLivenessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final kycState = ref.watch(kycViewModelProvider);
    final kycNotifier = ref.read(kycViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Liveness & Selfie Verification'),
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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Take a Quick Selfie',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppDimensions.spaceXs),
                      Text(
                        'This selfie is compared against your official government records to prevent fraud.',
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppDimensions.spaceLg),

                      // Camera Frame Oval Container
                      Container(
                        height: 260,
                        width: 200,
                        decoration: BoxDecoration(
                          color: theme.brightness == Brightness.dark
                              ? AppColors.surfaceDark
                              : AppColors.surfaceVariantLight,
                          borderRadius: BorderRadius.circular(130),
                          border: Border.all(
                            color: kycState.isLivenessVerified ? AppColors.income : AppColors.primary,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: kycState.isLivenessVerified
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(AppDimensions.spaceMd),
                                      decoration: const BoxDecoration(
                                        color: AppColors.income,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check_rounded,
                                        color: Colors.white,
                                        size: AppDimensions.iconLg,
                                      ),
                                    ),
                                    const SizedBox(height: AppDimensions.spaceSm),
                                    const Text(
                                      'Selfie Captured!',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.income,
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.face_rounded,
                                      size: 80,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                    ),
                                    const SizedBox(height: AppDimensions.spaceSm),
                                    Text(
                                      'Position face inside oval',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontSize: 12,
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spaceLg),

                      // Verification Checklist Card
                      PayFlowCard(
                        child: Column(
                          children: const [
                            _InstructionRow(
                              icon: Icons.wb_sunny_outlined,
                              text: 'Ensure you are in a well-lit environment.',
                            ),
                            SizedBox(height: AppDimensions.spaceSm),
                            _InstructionRow(
                              icon: Icons.face_retouching_natural_rounded,
                              text: 'Remove hats, glasses, or face coverings.',
                            ),
                            SizedBox(height: AppDimensions.spaceSm),
                            _InstructionRow(
                              icon: Icons.center_focus_strong_rounded,
                              text: 'Look straight at the camera and smile.',
                            ),
                          ],
                        ),
                      ),

                      if (kycState.livenessError != null) ...[
                        const SizedBox(height: AppDimensions.spaceMd),
                        PayFlowBadge(
                          label: kycState.livenessError!,
                          status: PayFlowBadgeStatus.danger,
                        ),
                      ],

                      const Spacer(),
                      const SizedBox(height: AppDimensions.spaceLg),

                      PayFlowButton(
                        text: kycState.isLivenessVerified ? 'Retake Selfie' : 'Capture Selfie Photo',
                        variant: kycState.isLivenessVerified
                            ? PayFlowButtonVariant.outline
                            : PayFlowButtonVariant.primary,
                        isLoading: kycState.isLoading,
                        onPressed: () {
                          kycNotifier.captureLiveness();
                        },
                      ),
                      const SizedBox(height: AppDimensions.spaceSm),

                      PayFlowButton(
                        text: 'Continue to Document Upload',
                        onPressed: () {
                          if (!kycState.isLivenessVerified) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please capture a selfie to proceed with verification.'),
                                backgroundColor: AppColors.expense,
                              ),
                            );
                            return;
                          }
                          context.push('/kyc/documents');
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

class _InstructionRow extends StatelessWidget {
  const _InstructionRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: AppDimensions.iconSm + 2, color: AppColors.primary),
        const SizedBox(width: AppDimensions.spaceSm + 2),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
          ),
        ),
      ],
    );
  }
}
