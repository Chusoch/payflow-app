import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/widgets/payflow_badge.dart';
import '../../../core/widgets/payflow_button.dart';
import '../../../core/widgets/payflow_card.dart';
import '../models/kyc_tier.dart';
import '../view_models/kyc_view_model.dart';

class KycReviewScreen extends ConsumerWidget {
  const KycReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final kycState = ref.watch(kycViewModelProvider);
    final kycNotifier = ref.read(kycViewModelProvider.notifier);
    final isIndividual = kycState.accountType == AccountType.individual;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Information'),
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
                        'Review Your Details',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spaceXs),
                      Text(
                        'Please verify that all information is accurate before submitting your KYC application.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppDimensions.spaceLg),

                      // Section 1: Account Category
                      _SectionHeader(
                        title: 'Account Category',
                        onEdit: () => context.push('/kyc/account-type'),
                      ),
                      const SizedBox(height: AppDimensions.spaceSm),
                      PayFlowCard(
                        child: _ReviewRow(
                          label: 'Account Type',
                          value: isIndividual ? 'Individual Personal Account' : 'Business Account',
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spaceLg),

                      // Section 2: Personal / Business Details
                      _SectionHeader(
                        title: isIndividual ? 'Personal Information' : 'Business Information',
                        onEdit: () => context.push('/kyc/personal-info'),
                      ),
                      const SizedBox(height: AppDimensions.spaceSm),
                      PayFlowCard(
                        child: Column(
                          children: isIndividual
                              ? [
                                  _ReviewRow(label: 'Full Name', value: '${kycState.firstName} ${kycState.lastName}'),
                                  const Divider(height: AppDimensions.spaceLg),
                                  _ReviewRow(label: 'Date of Birth', value: kycState.dob),
                                  const Divider(height: AppDimensions.spaceLg),
                                  _ReviewRow(label: 'Gender', value: kycState.gender),
                                  const Divider(height: AppDimensions.spaceLg),
                                  _ReviewRow(label: 'Nationality', value: kycState.nationality),
                                ]
                              : [
                                  _ReviewRow(label: 'Business Name', value: kycState.businessName),
                                  const Divider(height: AppDimensions.spaceLg),
                                  _ReviewRow(label: 'Business Type', value: kycState.businessType),
                                  const Divider(height: AppDimensions.spaceLg),
                                  _ReviewRow(
                                    label: 'RC / CAC Number',
                                    value: kycState.registrationNumber.isEmpty ? 'N/A' : kycState.registrationNumber,
                                  ),
                                  const Divider(height: AppDimensions.spaceLg),
                                  _ReviewRow(label: 'Business Email', value: kycState.businessEmail),
                                ],
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spaceLg),

                      // Section 3: Address Details
                      _SectionHeader(
                        title: 'Address Information',
                        onEdit: () => context.push('/kyc/address'),
                      ),
                      const SizedBox(height: AppDimensions.spaceSm),
                      PayFlowCard(
                        child: Column(
                          children: [
                            _ReviewRow(label: 'Street Address', value: kycState.addressLine),
                            const Divider(height: AppDimensions.spaceLg),
                            _ReviewRow(label: 'City & State', value: '${kycState.city}, ${kycState.stateName}'),
                            const Divider(height: AppDimensions.spaceLg),
                            _ReviewRow(label: 'Country', value: kycState.country),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spaceLg),

                      // Section 4: Identity Verification Summary
                      _SectionHeader(
                        title: 'Identity Verification',
                        onEdit: () => context.push('/kyc/identity'),
                      ),
                      const SizedBox(height: AppDimensions.spaceSm),
                      PayFlowCard(
                        child: Column(
                          children: [
                            _ReviewRow(
                              label: 'BVN Verification',
                              value: kycState.bvn.length == 11
                                  ? '${kycState.bvn.substring(0, 3)}****${kycState.bvn.substring(7)}'
                                  : 'Verified',
                              badge: const PayFlowBadge(label: 'VERIFIED', status: PayFlowBadgeStatus.success),
                            ),
                            const Divider(height: AppDimensions.spaceLg),
                            _ReviewRow(
                              label: 'NIN Verification',
                              value: kycState.nin.length == 11
                                  ? '${kycState.nin.substring(0, 3)}****${kycState.nin.substring(7)}'
                                  : 'Verified',
                              badge: const PayFlowBadge(label: 'VERIFIED', status: PayFlowBadgeStatus.success),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spaceLg),

                      // Section 5: Selfie & Document Upload
                      _SectionHeader(
                        title: 'Liveness & Document Attachments',
                        onEdit: () => context.push('/kyc/documents'),
                      ),
                      const SizedBox(height: AppDimensions.spaceSm),
                      PayFlowCard(
                        child: Column(
                          children: [
                            _ReviewRow(
                              label: 'Selfie Liveness Photo',
                              value: 'Captured & Passed',
                              badge: const PayFlowBadge(label: 'PASSED', status: PayFlowBadgeStatus.success),
                            ),
                            const Divider(height: AppDimensions.spaceLg),
                            _ReviewRow(
                              label: 'Government ID Document',
                              value: kycState.selectedDocType,
                              badge: const PayFlowBadge(label: 'ATTACHED', status: PayFlowBadgeStatus.info),
                            ),
                          ],
                        ),
                      ),

                      if (kycState.errorMessage != null) ...[
                        const SizedBox(height: AppDimensions.spaceMd),
                        PayFlowBadge(
                          label: kycState.errorMessage!,
                          status: PayFlowBadgeStatus.danger,
                        ),
                      ],

                      const Spacer(),
                      const SizedBox(height: AppDimensions.spaceLg),

                      PayFlowButton(
                        text: 'Submit KYC Verification',
                        isLoading: kycState.isLoading,
                        onPressed: () async {
                          final success = await kycNotifier.submitKyc();
                          if (success && context.mounted) {
                            context.push('/kyc/status');
                          }
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.onEdit,
  });

  final String title;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        TextButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: const Text('Edit', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.label,
    required this.value,
    this.badge,
  });

  final String label;
  final String value;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        // ignore: use_null_aware_elements
        if (badge != null) badge!,
      ],
    );
  }
}
