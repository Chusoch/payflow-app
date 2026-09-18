import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/payflow_card.dart';
import '../../../core/widgets/payflow_text_field.dart';
import '../../transfer/view_models/transfer_view_model.dart';
import '../view_models/services_view_model.dart';
import '../widgets/airtime_flow_sheet.dart';
import '../widgets/cable_tv_flow_sheet.dart';
import '../widgets/electricity_flow_sheet.dart';
import '../widgets/mobile_data_flow_sheet.dart';

class ServicesScreen extends ConsumerWidget {
  const ServicesScreen({super.key});

  void _onCategoryTapped(BuildContext context, String catId) {
    switch (catId) {
      case 'airtime':
        AirtimeFlowSheet.show(context);
        break;
      case 'data':
        MobileDataFlowSheet.show(context);
        break;
      case 'electricity':
        ElectricityFlowSheet.show(context);
        break;
      case 'cable':
        CableTvFlowSheet.show(context);
        break;
      default:
        AirtimeFlowSheet.show(context);
        break;
    }
  }

  void _onBillerSelected(BuildContext context, Beneficiary ben) {
    final cat = (ben.category ?? '').toLowerCase();
    final name = ben.name.toLowerCase();
    final serviceId = (ben.serviceId ?? '').toLowerCase();

    if (cat.contains('elec') ||
        name.contains('elec') ||
        serviceId.contains('elec') ||
        ben.bankName.toLowerCase().contains('elec')) {
      ElectricityFlowSheet.show(
        context,
        initialMeter: ben.accountOrPhone,
        initialDisco: ben.name.contains('Electric') ? ben.name : 'Ikeja Electric',
      );
    } else if (cat.contains('cable') ||
        name.contains('dstv') ||
        name.contains('gotv') ||
        name.contains('startimes') ||
        ben.bankName.toLowerCase().contains('cable')) {
      CableTvFlowSheet.show(
        context,
        initialSmartcard: ben.accountOrPhone,
        initialProvider: name.contains('gotv')
            ? 'GOtv'
            : (name.contains('startimes') ? 'Startimes' : 'DSTV'),
      );
    } else if (cat.contains('airtime') || ben.bankName.toLowerCase().contains('airtime')) {
      AirtimeFlowSheet.show(
        context,
        initialPhone: ben.accountOrPhone,
        initialNetwork: name.contains('airtel')
            ? 'Airtel'
            : (name.contains('glo')
                ? 'Glo'
                : (name.contains('9mobile') ? '9mobile' : 'MTN')),
      );
    } else {
      ElectricityFlowSheet.show(context, initialMeter: ben.accountOrPhone);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final servicesState = ref.watch(servicesViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bills & Services'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Bar
              const PayFlowTextField(
                hintText: 'Search service, biller, or merchant...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              const SizedBox(height: AppDimensions.spaceLg),

              // Saved Beneficiaries Horizontal Quick Actions Tray
              if (servicesState.savedBillers.isNotEmpty) ...[
                Text(
                  'Saved Billers & Beneficiaries',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceMd),

                SizedBox(
                  height: 95,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: servicesState.savedBillers.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: AppDimensions.spaceMd),
                    itemBuilder: (context, index) {
                      final biller = servicesState.savedBillers[index];
                      final isElec = biller.category == 'bills' &&
                              biller.name.toLowerCase().contains('elec') ||
                          biller.bankName.toLowerCase().contains('elec');
                      final isCable = biller.name.toLowerCase().contains('dstv') ||
                          biller.name.toLowerCase().contains('gotv') ||
                          biller.bankName.toLowerCase().contains('cable');
                      final icon = isElec
                          ? Icons.bolt_rounded
                          : (isCable ? Icons.tv_rounded : Icons.phone_android_rounded);
                      final iconColor = isElec
                          ? AppColors.pending
                          : (isCable ? AppColors.secondary : AppColors.primary);

                      return GestureDetector(
                        onTap: () => _onBillerSelected(context, biller),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: iconColor.withValues(alpha: 0.15),
                              child: Icon(icon, color: iconColor, size: 22),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: 72,
                              child: Text(
                                biller.name,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 72,
                              child: Text(
                                biller.accountOrPhone,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 9,
                                  color: theme.textTheme.bodySmall?.color
                                      ?.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceLg),
              ],

              // Primary Services Header
              Text(
                'Pay Utilities',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppDimensions.spaceMd),

              // Grid of Primary Service Cards
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: AppDimensions.spaceMd,
                  mainAxisSpacing: AppDimensions.spaceMd,
                  childAspectRatio: 1.35,
                ),
                itemCount: servicesState.categories.length,
                itemBuilder: (context, index) {
                  final cat = servicesState.categories[index];
                  return GestureDetector(
                    onTap: () => _onCategoryTapped(context, cat.id),
                    child: PayFlowCard(
                      padding: const EdgeInsets.all(AppDimensions.spaceMd),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(AppDimensions.spaceSm),
                                decoration: BoxDecoration(
                                  color: cat.color.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  cat.icon,
                                  color: cat.color,
                                  size: AppDimensions.iconSm + 4,
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: theme.dividerColor,
                                size: 14,
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cat.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                cat.description,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontSize: 10,
                                  color: theme.textTheme.bodyMedium?.color
                                      ?.withValues(alpha: 0.7),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppDimensions.spaceLg),

              // Saved Billers Section
              Text(
                'Saved Billers',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppDimensions.spaceMd),

              PayFlowCard(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.spaceSm + 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.bolt_rounded, color: Colors.amber),
                    ),
                    const SizedBox(width: AppDimensions.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ikeja Electric (Prepaid)',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Meter: 0192837465',
                            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => ElectricityFlowSheet.show(context),
                      child: const Text('Pay Now'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
