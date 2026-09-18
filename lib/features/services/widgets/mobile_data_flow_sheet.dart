import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/network_prefixes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/payflow_button.dart';
import '../../../core/widgets/payflow_text_field.dart';
import '../../../core/payment/providers/payment_provider.dart';
import '../../wallet/view_models/wallet_view_model.dart';
import '../view_models/services_view_model.dart';
import 'service_result_sheet.dart';
import 'service_review_sheet.dart';

class MobileDataFlowSheet extends ConsumerStatefulWidget {
  final String? initialPhone;
  final String? initialNetwork;

  const MobileDataFlowSheet({
    super.key,
    this.initialPhone,
    this.initialNetwork,
  });

  static Future<void> show(
    BuildContext context, {
    String? initialPhone,
    String? initialNetwork,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MobileDataFlowSheet(
        initialPhone: initialPhone,
        initialNetwork: initialNetwork,
      ),
    );
  }

  @override
  ConsumerState<MobileDataFlowSheet> createState() => _MobileDataFlowSheetState();
}

class _MobileDataFlowSheetState extends ConsumerState<MobileDataFlowSheet> {
  late final TextEditingController _phoneController;
  late String _selectedNetwork;
  DataPlan? _selectedPlan;
  String? _phoneError;
  String? _planError;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(
      text: widget.initialPhone ?? '08123456789',
    );
    _selectedNetwork = widget.initialNetwork ?? 'MTN';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _detectAndFetchPlans(_phoneController.text);
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _detectAndFetchPlans(String phone) {
    final detectedSlug = NetworkPrefixes.detectNetwork(phone);
    final mappedName = _networkSlugToName(detectedSlug);
    if (mappedName != _selectedNetwork) {
      setState(() {
        _selectedNetwork = mappedName;
        _selectedPlan = null;
      });
    }
    ref.read(servicesViewModelProvider.notifier).fetchDataPlans(detectedSlug);
  }

  String _networkSlugToName(String slug) {
    switch (slug.toLowerCase()) {
      case 'glo':
        return 'Glo';
      case 'airtel':
        return 'Airtel';
      case '9mobile':
        return '9mobile';
      case 'mtn':
      default:
        return 'MTN';
    }
  }

  void _onNetworkSelected(String netName) {
    setState(() {
      _selectedNetwork = netName;
      _selectedPlan = null;
    });
    ref.read(servicesViewModelProvider.notifier).fetchDataPlans(netName.toLowerCase());
  }

  void _proceedToReview() {
    final phone = _phoneController.text.trim();

    bool isValid = true;
    if (phone.length != 11 || !RegExp(r'^\d{11}$').hasMatch(phone)) {
      setState(() => _phoneError = 'Enter a valid 11-digit Nigerian phone number');
      isValid = false;
    }

    if (_selectedPlan == null) {
      setState(() => _planError = 'Please select a data plan');
      isValid = false;
    }

    if (!isValid) return;

    final plan = _selectedPlan!;
    final rootContext = context;
    Navigator.of(context).pop();

    ServiceReviewSheet.show(
      context: rootContext,
      serviceTitle: 'Mobile Data Purchase',
      serviceIcon: Icons.wifi_rounded,
      iconColor: const Color(0xFF10B981),
      providerName: _selectedNetwork,
      identifier: phone,
      identifierLabel: 'Phone Number',
      planOrDetail: '${plan.name} (${plan.validity})',
      amount: plan.price,
      onConfirm: (reviewContext, ref) async {
        final verification = await ref.read(walletViewModelProvider.notifier).payService(
              title: '$_selectedNetwork Data (${plan.name})',
              category: 'Data',
              amount: plan.price,
              identifier: phone,
              referencePrefix: 'PF-DATA-',
              narration: '$_selectedNetwork ${plan.name} Data',
              providerType: PaymentProviderType.vtpass,
            );

        if (!verification.isConfirmed) {
          throw Exception(verification.failureReason ?? 'Insufficient wallet balance for this data subscription.');
        }

        if (!reviewContext.mounted) return;
        final parentContext = Navigator.of(reviewContext).context;
        Navigator.of(reviewContext).pop();

        ServiceResultSheet.show(
          context: parentContext,
          isSuccess: true,
          serviceTitle: 'Mobile Data Subscription',
          providerName: _selectedNetwork,
          identifier: phone,
          amount: plan.price,
          reference: verification.transactionRef,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servicesState = ref.watch(servicesViewModelProvider);
    final walletState = ref.watch(walletViewModelProvider);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusLg),
        ),
      ),
      padding: EdgeInsets.only(
        left: AppDimensions.spaceLg,
        right: AppDimensions.spaceLg,
        top: AppDimensions.spaceLg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppDimensions.spaceLg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spaceLg),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppDimensions.spaceSm + 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.wifi_rounded,
                    color: Color(0xFF10B981),
                    size: AppDimensions.iconMd,
                  ),
                ),
                const SizedBox(width: AppDimensions.spaceMd),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Buy Mobile Data',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Select data bundle & duration',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spaceLg),

            // Phone Number Input with Auto MSISDN Network Detection
            PayFlowTextField(
              label: 'Phone Number',
              hintText: 'e.g. 08123456789',
              keyboardType: TextInputType.phone,
              controller: _phoneController,
              errorText: _phoneError,
              prefixIcon: const Icon(Icons.phone_rounded),
              onChanged: (val) {
                if (_phoneError != null) setState(() => _phoneError = null);
                if (val.trim().length >= 4) {
                  _detectAndFetchPlans(val.trim());
                }
              },
            ),
            const SizedBox(height: AppDimensions.spaceLg),

            // Select Network Provider Tabs
            Text(
              'Network Operator',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: AppDimensions.spaceSm),

            Row(
              children: servicesState.networks.map((net) {
                final isSelected = _selectedNetwork.toLowerCase() == net.toLowerCase();
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _onNetworkSelected(net),
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(vertical: AppDimensions.spaceSm + 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : theme.dividerColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          net,
                          style: TextStyle(
                            color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppDimensions.spaceLg),

            // Data Plans Section Header
            Text(
              'Select Data Plan',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            if (_planError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _planError!,
                  style: const TextStyle(color: AppColors.expense, fontSize: 12),
                ),
              ),
            const SizedBox(height: AppDimensions.spaceSm),

            // Data Plans Content State (Loading Skeleton vs Retry-on-Error vs Catalog List)
            if (servicesState.isLoadingDataPlans) ...[
              // Loading Skeleton
              Column(
                children: List.generate(
                  3,
                  (index) => Container(
                    margin: const EdgeInsets.only(bottom: AppDimensions.spaceSm),
                    padding: const EdgeInsets.all(AppDimensions.spaceMd),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(width: 120, height: 14, color: theme.dividerColor.withValues(alpha: 0.3)),
                            const SizedBox(height: 6),
                            Container(width: 80, height: 10, color: theme.dividerColor.withValues(alpha: 0.2)),
                          ],
                        ),
                        Container(width: 60, height: 16, color: theme.dividerColor.withValues(alpha: 0.3)),
                      ],
                    ),
                  ),
                ),
              ),
            ] else if (servicesState.dataPlansError != null) ...[
              // Retry-on-Error Banner
              Container(
                padding: const EdgeInsets.all(AppDimensions.spaceMd),
                decoration: BoxDecoration(
                  color: AppColors.expense.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  border: Border.all(color: AppColors.expense.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.expense),
                    const SizedBox(width: AppDimensions.spaceSm),
                    Expanded(
                      child: Text(
                        servicesState.dataPlansError!,
                        style: const TextStyle(fontSize: 12, color: AppColors.expense),
                      ),
                    ),
                    TextButton(
                      onPressed: () => ref
                          .read(servicesViewModelProvider.notifier)
                          .fetchDataPlans(_selectedNetwork.toLowerCase()),
                      child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Data Plan Catalog List
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: servicesState.dataPlans.length,
                separatorBuilder: (context, index) => const SizedBox(height: AppDimensions.spaceSm),
                itemBuilder: (context, index) {
                  final plan = servicesState.dataPlans[index];
                  final isSelected = _selectedPlan?.id == plan.id;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedPlan = plan;
                        _planError = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(AppDimensions.spaceMd),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : theme.dividerColor.withValues(alpha: 0.4),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plan.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'Validity: ${plan.validity}',
                                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11),
                              ),
                            ],
                          ),
                          Text(
                            '₦${plan.price.toStringAsFixed(2)}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isSelected ? AppColors.primary : theme.textTheme.titleMedium?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],

            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Available: ₦${walletState.mainBalance.toStringAsFixed(2)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 11,
                  color: AppColors.income,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spaceXl),

            PayFlowButton(
              text: 'Continue to Review',
              icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              onPressed: _proceedToReview,
            ),
          ],
        ),
      ),
    );
  }
}
