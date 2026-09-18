import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payflow/core/notifications/notification_service.dart';
import 'package:payflow/features/notifications/models/notification_item.dart';
import 'package:payflow/features/notifications/view_models/notification_view_model.dart';
import 'package:payflow/features/notifications/views/notification_center_screen.dart';
import 'package:payflow/features/notifications/views/notification_preferences_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('NotificationViewModel Unit Tests', () {
    test('Initializes with default notifications and calculates unread count', () async {
      final notifService = NotificationService();
      final vm = NotificationViewModel(notifService);
      await vm.init();

      expect(vm.state.notifications.isNotEmpty, isTrue);
      expect(vm.state.unreadCount, greaterThanOrEqualTo(1));
    });

    test('Category filtering filters notifications by category correctly', () async {
      final notifService = NotificationService();
      final vm = NotificationViewModel(notifService);
      await vm.init();

      vm.setCategoryFilter(NotificationCategory.security);
      expect(
        vm.state.filteredNotifications.every((n) => n.category == NotificationCategory.security),
        isTrue,
      );

      vm.setCategoryFilter(null);
      expect(vm.state.filteredNotifications.length, equals(vm.state.notifications.length));
    });

    test('markAsRead and markAllAsRead update read status and unread count', () async {
      final notifService = NotificationService();
      final vm = NotificationViewModel(notifService);
      await vm.init();

      final firstId = vm.state.notifications.first.id;
      vm.markAsRead(firstId);
      expect(vm.state.notifications.firstWhere((n) => n.id == firstId).isRead, isTrue);

      vm.markAllAsRead();
      expect(vm.state.unreadCount, equals(0));
    });

    test('Security category preference is locked ON and cannot be disabled', () async {
      final notifService = NotificationService();
      final vm = NotificationViewModel(notifService);
      await vm.init();

      await vm.toggleCategoryPreference(NotificationCategory.security, false);
      expect(vm.state.isSecurityEnabled, isTrue);

      await vm.toggleCategoryPreference(NotificationCategory.transactions, false);
      expect(vm.state.isTransactionsEnabled, isFalse);
    });

    test('NotificationService.initialize executes safely without crashing', () async {
      final notifService = NotificationService();
      await expectLater(notifService.initialize(), completes);
    });

    test('NotificationService startRealtimeNotifications and stopRealtimeNotifications manage user id safely', () {
      final notifService = NotificationService();
      notifService.startRealtimeNotifications('+2348012345678');
      expect(notifService.activeUserId, equals('+2348012345678'));

      notifService.stopRealtimeNotifications();
      expect(notifService.activeUserId, isNull);

      notifService.startFirestoreNotificationStream('08012345678');
      expect(notifService.activeUserId, equals('08012345678'));

      notifService.stopFirestoreNotificationStream();
      expect(notifService.activeUserId, isNull);
    });

    test('showInAppBanner executes safely without throwing when unmounted or offscreen', () {
      final notifService = NotificationService();
      expect(
        () => notifService.showInAppBanner(title: 'Transfer Received', body: '₦50 received from Chukwuma'),
        returnsNormally,
      );
    });

    test('Incoming real-time notification increments unreadCount immediately', () async {
      final notifService = NotificationService();
      final vm = NotificationViewModel(notifService);
      await vm.init();

      final initialUnread = vm.state.unreadCount;
      vm.addNotification(
        NotificationItem(
          id: 'TEST-TRANSFER-${DateTime.now().millisecondsSinceEpoch}',
          title: 'Transfer Received',
          body: '₦5,000.00 received from Bob',
          category: NotificationCategory.transactions,
          timestamp: DateTime.now(),
          isRead: false,
        ),
      );

      expect(vm.state.unreadCount, equals(initialUnread + 1));
      expect(vm.state.notifications.any((n) => n.title == 'Transfer Received'), isTrue);
    });
  });

  group('Notification Widget Tests', () {
    testWidgets('NotificationCenterScreen renders category chips and list items', (tester) async {
      final container = ProviderContainer();
      final vm = container.read(notificationViewModelProvider.notifier);
      await vm.init();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: NotificationCenterScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Transactions'), findsOneWidget);
      expect(find.text('Security'), findsOneWidget);
      expect(find.text('Promotions'), findsOneWidget);
    });

    testWidgets('NotificationPreferencesScreen renders alert categories and switches', (tester) async {
      final container = ProviderContainer();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: NotificationPreferencesScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Notification Preferences'), findsOneWidget);
      expect(find.text('Transactions & Payments'), findsOneWidget);
      expect(find.text('Security & Account Alerts'), findsOneWidget);
      expect(find.text('Promotions & Feature Updates'), findsOneWidget);
    });
  });
}
