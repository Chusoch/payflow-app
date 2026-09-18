import 'package:flutter/material.dart';
import '../constants/app_dimensions.dart';
import 'payflow_card.dart';

class PayFlowStatCard extends StatelessWidget {
  const PayFlowStatCard({
    super.key,
    required this.title,
    required this.amount,
    required this.icon,
    this.iconBgColor,
    this.iconColor,
    this.subtitle,
    this.onTap,
  });

  final String title;
  final String amount;
  final IconData icon;
  final Color? iconBgColor;
  final Color? iconColor;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PayFlowCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(AppDimensions.spaceSm),
                decoration: BoxDecoration(
                  color: iconBgColor ??
                      theme.colorScheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: AppDimensions.iconSm,
                  color: iconColor ?? theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceSm),
          Text(
            amount,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppDimensions.spaceXs),
            Text(
              subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
