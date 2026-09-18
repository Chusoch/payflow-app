import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../constants/app_dimensions.dart';

enum PayFlowBadgeStatus { success, warning, danger, info }

class PayFlowBadge extends StatelessWidget {
  const PayFlowBadge({
    super.key,
    required this.label,
    this.status = PayFlowBadgeStatus.info,
    this.customBgColor,
    this.customTextColor,
  });

  final String label;
  final PayFlowBadgeStatus status;
  final Color? customBgColor;
  final Color? customTextColor;

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;

    switch (status) {
      case PayFlowBadgeStatus.success:
        bgColor = AppColors.income.withValues(alpha: 0.15);
        textColor = AppColors.income;
        break;
      case PayFlowBadgeStatus.warning:
        bgColor = AppColors.pending.withValues(alpha: 0.15);
        textColor = AppColors.pending;
        break;
      case PayFlowBadgeStatus.danger:
        bgColor = AppColors.expense.withValues(alpha: 0.15);
        textColor = AppColors.expense;
        break;
      case PayFlowBadgeStatus.info:
        bgColor = AppColors.info.withValues(alpha: 0.15);
        textColor = AppColors.info;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spaceSm + 2,
        vertical: AppDimensions.spaceXs,
      ),
      decoration: BoxDecoration(
        color: customBgColor ?? bgColor,
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: customTextColor ?? textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
