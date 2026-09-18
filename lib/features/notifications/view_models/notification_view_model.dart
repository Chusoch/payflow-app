import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/notifications/notification_service.dart';
import '../../auth/models/auth_state.dart';
import '../../auth/view_models/auth_view_model.dart';
import '../models/notification_item.dart';

class NotificationState {
  final List<NotificationItem> notifications;
  final NotificationCategory? selectedCategoryFilter;
  final bool isTransactionsEnabled;
  final bool isSecurityEnabled; // Always true (locked security alerts)
  final bool isPromotionsEnabled;
  final bool isLoading;

  const NotificationState({
    this.notifications = const [],
    this.selectedCategoryFilter,
    this.isTransactionsEnabled = true,
    this.isSecurityEnabled = true,
    this.isPromotionsEnabled = true,
    this.isLoading = false,
  });

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  List<NotificationItem> get filteredNotifications {
    if (selectedCategoryFilter == null) {
      return notifications;
    }
    return notifications
        .where((n) => n.category == selectedCategoryFilter)
        .toList();
  }

  NotificationState copyWith({
    List<NotificationItem>? notifications,
    NotificationCategory? selectedCategoryFilter,
    bool clearCategoryFilter = false,
    bool? isTransactionsEnabled,
    bool? isSecurityEnabled,
    bool? isPromotionsEnabled,
    bool? isLoading,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      selectedCategoryFilter: clearCategoryFilter
          ? null
          : (selectedCategoryFilter ?? this.selectedCategoryFilter),
      isTransactionsEnabled: isTransactionsEnabled ?? this.isTransactionsEnabled,
      isSecurityEnabled: true, // Always locked ON
      isPromotionsEnabled: isPromotionsEnabled ?? this.isPromotionsEnabled,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class NotificationViewModel extends StateNotifier<NotificationState> {
  static const String _keyNotifItems = 'payflow_notif_items';
  static const String _keyPrefTransactions = 'payflow_notif_pref_transactions';
  static const String _keyPrefPromotions = 'payflow_notif_pref_promotions';

  final NotificationService _notificationService;
  final Ref? _ref;
  StreamSubscription<NotificationItem>? _subscription;
  final List<StreamSubscription> _firestoreSubs = [];
  SharedPreferences? _prefs;

  NotificationViewModel(this._notificationService, [this._ref])
      : super(const NotificationState()) {
    init();
  }

  Future<void> init() async {
    state = state.copyWith(isLoading: true);
    try {
      _prefs = await SharedPreferences.getInstance();
      final isTxEnabled = _prefs?.getBool(_keyPrefTransactions) ?? true;
      final isPromoEnabled = _prefs?.getBool(_keyPrefPromotions) ?? true;

      // Load saved notifications
      final savedJsonStr = _prefs?.getString(_keyNotifItems);
      List<NotificationItem> loadedItems = [];
      if (savedJsonStr != null && savedJsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(savedJsonStr);
        loadedItems = decoded.map((e) => NotificationItem.fromJson(e)).toList();
      } else {
        // Initial sample notifications for demonstration
        loadedItems = [
          NotificationItem(
            id: 'NOTIF-INIT-1',
            title: 'Welcome to PayFlow',
            body: 'Your account is active. Explore transactions, utility payments, and security tools.',
            category: NotificationCategory.promotions,
            timestamp: DateTime.now().subtract(const Duration(hours: 2)),
            isRead: false,
          ),
          NotificationItem(
            id: 'NOTIF-INIT-2',
            title: 'Account Security Enabled',
            body: 'Biometric and 4-digit PIN authentication are active for your wallet.',
            category: NotificationCategory.security,
            timestamp: DateTime.now().subtract(const Duration(hours: 5)),
            isRead: true,
          ),
        ];
      }

      state = state.copyWith(
        notifications: loadedItems,
        isTransactionsEnabled: isTxEnabled,
        isPromotionsEnabled: isPromoEnabled,
        isLoading: false,
      );

      // Listen for incoming notifications broadcast from NotificationService
      _subscription?.cancel();
      _subscription = _notificationService.onNotificationReceived.listen((item) {
        addNotification(item);
      });

      // Bind reactive Firestore inbox listener
      _bindFirestoreNotifications();

      // Listen for auth transitions to re-bind Firestore listener
      if (_ref != null) {
        _ref.listen<AuthState>(authViewModelProvider, (previous, next) {
          if (next.phoneNumber != previous?.phoneNumber ||
              next.status != previous?.status ||
              next.user?.id != previous?.user?.id) {
            _bindFirestoreNotifications();
          }
        });
      }

      try {
        FirebaseAuth.instance.authStateChanges().listen((user) {
          if (user != null) {
            _bindFirestoreNotifications();
          }
        });
      } catch (_) {}
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  void refreshNotifications() {
    _bindFirestoreNotifications();
  }

  void _bindFirestoreNotifications() {
    for (final sub in _firestoreSubs) {
      sub.cancel();
    }
    _firestoreSubs.clear();

    final authState = _ref?.read(authViewModelProvider);
    final candidateIds = <String>{};

    void addCandidate(String? raw) {
      if (raw == null) return;
      final clean = raw.trim();
      if (clean.isEmpty) return;
      candidateIds.add(clean);
      if (clean.startsWith('+234') && clean.length == 14) {
        candidateIds.add('0${clean.substring(4)}');
        candidateIds.add(clean.substring(1));
        candidateIds.add(clean.substring(4)); // 10-digit account/phone number
      } else if (clean.startsWith('0') && clean.length == 11) {
        candidateIds.add('+234${clean.substring(1)}');
        candidateIds.add('234${clean.substring(1)}');
        candidateIds.add(clean.substring(1)); // 10-digit account/phone number
      } else if (clean.startsWith('234') && clean.length == 13) {
        candidateIds.add('+$clean');
        candidateIds.add('0${clean.substring(3)}');
        candidateIds.add(clean.substring(3)); // 10-digit account/phone number
      } else if (clean.length == 10 && !clean.startsWith('0')) {
        candidateIds.add('0$clean');
        candidateIds.add('+234$clean');
        candidateIds.add('234$clean');
      }
    }

    addCandidate(authState?.phoneNumber);
    addCandidate(authState?.user?.id);
    addCandidate(authState?.user?.phoneNumber);
    addCandidate(_ref?.read(authRepositoryProvider).getAuthenticatedPhone());
    addCandidate(_notificationService.activeUserId);
    try {
      addCandidate(FirebaseAuth.instance.currentUser?.uid);
      addCandidate(FirebaseAuth.instance.currentUser?.phoneNumber);
    } catch (_) {}

    if (candidateIds.isEmpty) return;

    try {
      if (FirebaseAuth.instance.currentUser == null) {
        () async {
          try {
            final prefs = await SharedPreferences.getInstance();
            final token = prefs.getString('payflow_custom_token');
            if (token != null &&
                token.isNotEmpty &&
                token.split('.').length == 3 &&
                !token.startsWith('mock_')) {
              await FirebaseAuth.instance.signInWithCustomToken(token);
            }
          } catch (e) {
            debugPrint('[NotificationViewModel] Firebase custom token sign-in notice: $e');
          }
        }();
      }
    } catch (_) {}

    for (final id in candidateIds) {
      try {
        final sub = FirebaseFirestore.instance
            .collection('users')
            .doc(id)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots()
            .listen(
          (snapshot) {
            final firestoreItems = <NotificationItem>[];
            for (final doc in snapshot.docs) {
              final data = doc.data();
              final title = data['title']?.toString() ?? 'PayFlow Notification';
              final body = data['body']?.toString() ?? '';
              final rawType = (data['type'] ?? '').toString().toLowerCase();
              final isPromo = rawType.contains('promo') || rawType.contains('offer');
              final isSecurity = rawType.contains('security') || rawType.contains('login') || rawType.contains('pin');
              final category = isPromo
                  ? NotificationCategory.promotions
                  : (isSecurity
                      ? NotificationCategory.security
                      : NotificationCategory.transactions);
              final timestamp = DateTime.tryParse(data['createdAt']?.toString() ?? '') ?? DateTime.now();
              final isRead = data['read'] == true;

              firestoreItems.add(
                NotificationItem(
                  id: doc.id,
                  title: title,
                  body: body,
                  category: category,
                  timestamp: timestamp,
                  isRead: isRead,
                  payload: data,
                ),
              );
            }

            if (firestoreItems.isNotEmpty) {
              // Merge with state.notifications, avoiding duplicates by id
              final existingIds = firestoreItems.map((e) => e.id).toSet();
              final remaining = state.notifications.where((e) => !existingIds.contains(e.id)).toList();
              final merged = [...firestoreItems, ...remaining];
              merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));
              state = state.copyWith(notifications: merged, isLoading: false);
              _saveNotifications();
            }
          },
          onError: (err) {
            debugPrint('[NotificationViewModel] Firestore inbox query notice for $id: $err');
          },
        );
        _firestoreSubs.add(sub);
      } catch (e) {
        debugPrint('[NotificationViewModel] Could not bind Firestore inbox stream for $id: $e');
      }
    }
  }

  Future<void> _saveNotifications() async {
    try {
      final jsonList = state.notifications.map((e) => e.toJson()).toList();
      await _prefs?.setString(_keyNotifItems, jsonEncode(jsonList));
    } catch (_) {}
  }

  void addNotification(NotificationItem item) {
    // Check user category preference before displaying/adding
    if (item.category == NotificationCategory.transactions && !state.isTransactionsEnabled) {
      return;
    }
    if (item.category == NotificationCategory.promotions && !state.isPromotionsEnabled) {
      return;
    }

    final exists = state.notifications.any((n) => n.id == item.id);
    if (exists) return;

    final updated = [item, ...state.notifications];
    state = state.copyWith(notifications: updated);
    _saveNotifications();
  }

  void markAsRead(String id) {
    final updated = state.notifications.map((n) {
      if (n.id == id) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();

    state = state.copyWith(notifications: updated);
    _saveNotifications();
  }

  void markAllAsRead() {
    final updated = state.notifications.map((n) => n.copyWith(isRead: true)).toList();
    state = state.copyWith(notifications: updated);
    _saveNotifications();
  }

  void setCategoryFilter(NotificationCategory? category) {
    if (category == null) {
      state = state.copyWith(clearCategoryFilter: true);
    } else {
      state = state.copyWith(selectedCategoryFilter: category);
    }
  }

  Future<void> toggleCategoryPreference(NotificationCategory category, bool enabled) async {
    if (category == NotificationCategory.security) {
      // Security notifications are locked ON
      return;
    }

    if (category == NotificationCategory.transactions) {
      await _prefs?.setBool(_keyPrefTransactions, enabled);
      state = state.copyWith(isTransactionsEnabled: enabled);
    } else if (category == NotificationCategory.promotions) {
      await _prefs?.setBool(_keyPrefPromotions, enabled);
      state = state.copyWith(isPromotionsEnabled: enabled);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    for (final sub in _firestoreSubs) {
      sub.cancel();
    }
    _firestoreSubs.clear();
    super.dispose();
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final notificationViewModelProvider =
    StateNotifierProvider<NotificationViewModel, NotificationState>((ref) {
  final service = ref.watch(notificationServiceProvider);
  return NotificationViewModel(service, ref);
});
