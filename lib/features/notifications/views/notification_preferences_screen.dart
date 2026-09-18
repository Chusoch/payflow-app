import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/widgets/payflow_card.dart';
import '../models/notification_item.dart';
import '../view_models/notification_view_model.dart';

class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(notificationViewModelProvider);
    final notifier = ref.read(notificationViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Preferences'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Alert Categories',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Customize which notifications you receive from PayFlow.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: AppDimensions.spaceLg),
              PayFlowCard(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.receipt_long_rounded),
                      title: const Text('Transactions & Payments'),
                      subtitle: const Text('Transfer receipts, wallet funding, and bill payment confirmations'),
                      value: state.isTransactionsEnabled,
                      onChanged: (value) {
                        notifier.toggleCategoryPreference(NotificationCategory.transactions, value);
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.shield_rounded),
                      title: const Text('Security & Account Alerts'),
                      subtitle: const Text('Logins, PIN changes, and biometric updates (Mandatory)'),
                      value: true, // Always locked ON
                      onChanged: null, // Disabled toggle
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.campaign_rounded),
                      title: const Text('Promotions & Feature Updates'),
                      subtitle: const Text('Special offers, news, and new PayFlow capabilities'),
                      value: state.isPromotionsEnabled,
                      onChanged: (value) {
                        notifier.toggleCategoryPreference(NotificationCategory.promotions, value);
                      },
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
