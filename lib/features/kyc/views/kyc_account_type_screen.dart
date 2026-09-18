import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/payflow_button.dart';
import '../../../core/widgets/payflow_card.dart';
import '../models/kyc_tier.dart';
import '../view_models/kyc_view_model.dart';

class KycAccountTypeScreen extends ConsumerWidget {
  const KycAccountTypeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final kycState = ref.watch(kycViewModelProvider);
    final kycNotifier = ref.read(kycViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Account Type'),
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
                        'Choose Account Category',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spaceXs),
                      Text(
                        'Select the category that best matches your banking needs.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppDimensions.spaceLg),

                      // Individual Option Card
                      _AccountTypeCard(
                        title: 'Individual Account',
                        subtitle: 'For personal daily banking, transfers, bill payments, and savings.',
                        icon: Icons.person_outline_rounded,
                        isSelected: kycState.accountType == AccountType.individual,
                        onTap: () {
                          kycNotifier.setAccountType(AccountType.individual);
                        },
                      ),

                      const Spacer(),
                      const SizedBox(height: AppDimensions.spaceLg),

                      PayFlowButton(
                        text: 'Continue',
                        onPressed: () {
                          context.push('/kyc/personal-info');
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

class _AccountTypeCard extends StatelessWidget {
  const _AccountTypeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: PayFlowCard(
        variant: isSelected ? PayFlowCardVariant.standard : PayFlowCardVariant.outlined,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppDimensions.spaceMd),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : theme.brightness == Brightness.dark
                        ? AppColors.surfaceVariantDark
                        : AppColors.surfaceVariantLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.primary : theme.colorScheme.onSurface,
                size: AppDimensions.iconLg,
              ),
            ),
            const SizedBox(width: AppDimensions.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppColors.primary : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? AppColors.primary : theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}
