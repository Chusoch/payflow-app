import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/payflow_card.dart';
import '../models/notification_item.dart';
import '../view_models/notification_view_model.dart';

class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends ConsumerState<NotificationCenterScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationViewModelProvider.notifier).refreshNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(notificationViewModelProvider);
    final notifier = ref.read(notificationViewModelProvider.notifier);

    final notifications = state.filteredNotifications;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: () => notifier.markAllAsRead(),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Category Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spaceMd,
                vertical: AppDimensions.spaceSm,
              ),
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: state.selectedCategoryFilter == null,
                    onSelected: (_) => notifier.setCategoryFilter(null),
                  ),
                  const SizedBox(width: AppDimensions.spaceSm),
                  FilterChip(
                    label: const Text('Transactions'),
                    selected: state.selectedCategoryFilter == NotificationCategory.transactions,
                    onSelected: (_) => notifier.setCategoryFilter(NotificationCategory.transactions),
                  ),
                  const SizedBox(width: AppDimensions.spaceSm),
                  FilterChip(
                    label: const Text('Security'),
                    selected: state.selectedCategoryFilter == NotificationCategory.security,
                    onSelected: (_) => notifier.setCategoryFilter(NotificationCategory.security),
                  ),
                  const SizedBox(width: AppDimensions.spaceSm),
                  FilterChip(
                    label: const Text('Promotions'),
                    selected: state.selectedCategoryFilter == NotificationCategory.promotions,
                    onSelected: (_) => notifier.setCategoryFilter(NotificationCategory.promotions),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Notification List grouped by Date
            Expanded(
              child: notifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_none_rounded,
                            size: 64,
                            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: AppDimensions.spaceMd),
                          Text(
                            'No notifications found',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Alerts for transactions and security will appear here.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppDimensions.spaceMd),
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        final item = notifications[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppDimensions.spaceSm),
                          child: _NotificationCard(
                            item: item,
                            onTap: () {
                              notifier.markAsRead(item.id);
                              final txRef = item.payload?['transactionRef'] as String?;
                              if (txRef != null && txRef.isNotEmpty) {
                                context.push('/transaction-detail', extra: txRef);
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.onTap,
  });

  final NotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color iconBg;
    IconData iconData;
    switch (item.category) {
      case NotificationCategory.transactions:
        iconBg = AppColors.income.withValues(alpha: 0.15);
        iconData = Icons.receipt_long_rounded;
        break;
      case NotificationCategory.security:
        iconBg = AppColors.primary.withValues(alpha: 0.15);
        iconData = Icons.shield_rounded;
        break;
      case NotificationCategory.promotions:
        iconBg = AppColors.secondary.withValues(alpha: 0.15);
        iconData = Icons.campaign_rounded;
        break;
    }

    return PayFlowCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: iconBg,
            radius: 20,
            child: Icon(
              iconData,
              color: item.category == NotificationCategory.transactions
                  ? AppColors.income
                  : AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: AppDimensions.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: item.isRead ? FontWeight.w600 : FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (!item.isRead)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(left: 6),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceSm),
                Text(
                  _formatTimestamp(item.timestamp),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 11,
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
