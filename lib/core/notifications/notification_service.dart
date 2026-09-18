import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../firebase_options.dart';
import '../network/api_client.dart';
import '../router/app_router.dart';
import '../../features/home/models/transaction_item.dart';
import '../../features/notifications/models/notification_item.dart';
import '../../features/wallet/widgets/transaction_detail_sheet.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Graceful fallback if Firebase is uninitialized
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final StreamController<NotificationItem> _notificationStreamController =
      StreamController<NotificationItem>.broadcast();

  Stream<NotificationItem> get onNotificationReceived => _notificationStreamController.stream;

  bool _isInitialized = false;
  String? _fcmToken;
  final List<StreamSubscription> _firestoreSubscriptions = [];
  String? _activeUserId;
  final Set<String> _processedNotificationDocIds = <String>{};

  String? get fcmToken => _fcmToken;
  bool get isInitialized => _isInitialized;
  String? get activeUserId => _activeUserId;

  @visibleForTesting
  set isInitialized(bool value) => _isInitialized = value;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Guard against calling platform methods before Flutter engine/Activity binding is complete
    WidgetsFlutterBinding.ensureInitialized();

    // 1. Initialize Local Notifications Plugin (Mobile only)
    if (!kIsWeb) {
      try {
        const AndroidInitializationSettings initializationSettingsAndroid =
            AndroidInitializationSettings('@mipmap/ic_launcher');
        const DarwinInitializationSettings initializationSettingsDarwin =
            DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

        const InitializationSettings initSettings = InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

        try {
          await _localNotifications.initialize(
            initSettings,
            onDidReceiveNotificationResponse: (response) {
              if (response.payload != null && response.payload!.isNotEmpty) {
                try {
                  final json = jsonDecode(response.payload!);
                  final item = NotificationItem.fromJson(json);
                  _notificationStreamController.add(item);
                } catch (_) {}
              }
            },
          );
        } catch (initErr) {
          debugPrint('[NotificationService] Primary Android notification initialization failed: $initErr. Attempting fallback icon.');
          // Fallback gracefully to standard drawable ic_launcher if mipmap lookup fails
          try {
            const fallbackSettings = InitializationSettings(
              android: AndroidInitializationSettings('ic_launcher'),
              iOS: initializationSettingsDarwin,
            );
            await _localNotifications.initialize(fallbackSettings);
          } catch (fallbackErr) {
            debugPrint('[NotificationService] Fallback notification initialization failed: $fallbackErr');
          }
        }

        // 2. Create Android Notification Channels
        try {
          const androidTransactionsChannel = AndroidNotificationChannel(
            'transactions_channel',
            'Transactions & Payments',
            description: 'High-priority notifications for money transfers, wallet funding, and bill payments.',
            importance: Importance.high,
          );

          const androidSecurityChannel = AndroidNotificationChannel(
            'security_channel',
            'Security & Account Alerts',
            description: 'High-priority notifications for logins, PIN changes, and security events.',
            importance: Importance.high,
          );

          const androidPromotionsChannel = AndroidNotificationChannel(
            'promotions_channel',
            'Promotions & Updates',
            description: 'Standard notifications for PayFlow offers, news, and features.',
            importance: Importance.defaultImportance,
          );

          final androidImplementation = _localNotifications
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

          if (androidImplementation != null) {
            await androidImplementation.createNotificationChannel(androidTransactionsChannel);
            await androidImplementation.createNotificationChannel(androidSecurityChannel);
            await androidImplementation.createNotificationChannel(androidPromotionsChannel);
          }
        } catch (channelErr) {
          debugPrint('[NotificationService] Android notification channel creation fallback: $channelErr');
        }
      } catch (e) {
        debugPrint('[NotificationService] Local notifications init fallback: $e');
      }
    } else {
      debugPrint('[NotificationService] Web environment detected: skipping native local notification channels.');
    }

    // 3. Gracefully Initialize Firebase Core & FCM if credentials exist
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      debugPrint('[NotificationService] Firebase initialized successfully!');

      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

        // Handle foreground FCM messages with real-time in-app notification banner
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          final title = message.notification?.title ?? message.data['title'] ?? 'PayFlow Notification';
          final body = message.notification?.body ?? message.data['body'] ?? '';
          final type = message.data['type'] ?? message.data['category'] ?? 'transactions';
          final category = type == 'promotions'
              ? NotificationCategory.promotions
              : (type == 'security' ? NotificationCategory.security : NotificationCategory.transactions);

          showNotification(
            title: title,
            body: body,
            category: category,
            payload: message.data,
          );

          showInAppBanner(title: title, body: body, payload: message.data);
        });

        // Handle background/terminated message taps (Deep link into TransactionDetailSheet)
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          _handleMessageTap(message);
        });

        FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
          if (message != null) {
            _handleMessageTap(message);
          }
        });

        // Get FCM token and register with backend (mobile only; Web FCM requires VAPID key)
        _fcmToken = await FirebaseMessaging.instance.getToken();
        if (_fcmToken != null) {
          debugPrint('[NotificationService] FCM Token retrieved: $_fcmToken');
          registerDeviceTokenWithBackend();
        }
      } else {
        debugPrint('[NotificationService] Web environment: skipping native FCM background handler and listeners.');
      }
    } catch (e) {
      debugPrint('[NotificationService] Firebase init fallback (local simulation mode active): $e');
    }

    _isInitialized = true;
  }

  /// Sends the current FCM token to the backend POST /v1/devices/register endpoint.
  Future<void> registerDeviceTokenWithBackend() async {
    if (kIsWeb) return;
    try {
      final token = _fcmToken ?? await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      _fcmToken = token;

      final client = ApiClient();
      final response = await client.post('/v1/devices/register', body: {'fcm_token': token});
      if (response.statusCode == 200) {
        debugPrint('[NotificationService] FCM device token registered with backend successfully.');
      }
    } catch (e) {
      debugPrint('[NotificationService] Device token registration attempt: $e');
    }
  }

  /// Handles deep-linking into TransactionDetailSheet on background/terminated notification tap.
  void _handleMessageTap(RemoteMessage message) {
    final data = message.data;
    final reference = data['reference'] ?? data['transactionId'] ?? 'PF-TXN-${DateTime.now().millisecondsSinceEpoch}';
    final amount = double.tryParse(data['amount']?.toString() ?? '0.00') ?? 0.0;
    final type = data['type'] ?? 'payment';

    final txn = TransactionItem(
      id: reference,
      title: message.notification?.title ?? 'Transaction Details',
      category: type == 'vtpass' ? 'Utility Bill' : 'Wallet Funding',
      amount: amount,
      isCredit: true,
      timestamp: DateTime.now(),
      status: 'Successful',
      reference: reference,
    );

    final navContext = rootNavigatorKey.currentContext;
    if (navContext != null && navContext.mounted) {
      TransactionDetailSheet.show(navContext, txn);
    }
  }

  /// Request permissions on Android 13+ and iOS (typically triggered post-onboarding)
  Future<bool> requestPermissions() async {
    if (kIsWeb) return true;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (_) {
      // Fallback for local testing environments
      return true;
    }
  }

  /// Displays a floating in-app notification banner if the app is active in the foreground
  void showInAppBanner({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) {
    try {
      final messenger = rootScaffoldMessengerKey.currentState ??
          (rootNavigatorKey.currentContext != null
              ? ScaffoldMessenger.maybeOf(rootNavigatorKey.currentContext!)
              : null);

      if (messenger != null) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.notifications_active_rounded, color: Color(0xFF10B981), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                      ),
                      if (body.isNotEmpty)
                        Text(
                          body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (_) {}
  }

  /// Starts a real-time Firestore snapshot listener targeting the current user's notifications.
  /// Skips the initial query snapshot on startup so historical notifications are not re-alerted.
  /// When a new document arrives while the app is active, it shows an in-app banner and broadcasts
  /// the event to [onNotificationReceived] (which auto-triggers [refreshWallet()]).
  void startRealtimeNotifications(String currentUserId) {
    final trimmedId = currentUserId.trim();
    if (trimmedId.isEmpty) return;

    if (_activeUserId == trimmedId && _firestoreSubscriptions.isNotEmpty) {
      return;
    }

    stopRealtimeNotifications();
    _activeUserId = trimmedId;

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
            debugPrint('[AuthService] Firebase custom token sign-in warning: $e');
          }
        }();
      }
    } catch (_) {}

    final candidateIds = <String>{trimmedId};
    if (trimmedId.startsWith('+234') && trimmedId.length == 14) {
      candidateIds.add('0${trimmedId.substring(4)}');
      candidateIds.add(trimmedId.substring(1));
    } else if (trimmedId.startsWith('0') && trimmedId.length == 11) {
      candidateIds.add('+234${trimmedId.substring(1)}');
      candidateIds.add('234${trimmedId.substring(1)}');
    } else if (trimmedId.startsWith('234') && trimmedId.length == 13) {
      candidateIds.add('+$trimmedId');
      candidateIds.add('0${trimmedId.substring(3)}');
    }

    for (final id in candidateIds) {
      try {
        bool isInitial = true;
        final sub = FirebaseFirestore.instance
            .collection('users')
            .doc(id)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .limit(1)
            .snapshots()
            .listen(
          (snapshot) {
            if (isInitial) {
              isInitial = false;
              for (final doc in snapshot.docs) {
                _processedNotificationDocIds.add(doc.id);
              }
              return;
            }

            for (final change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added) {
                final docId = change.doc.id;
                if (_processedNotificationDocIds.contains(docId)) {
                  continue;
                }
                _processedNotificationDocIds.add(docId);

                final data = change.doc.data();
                if (data == null) continue;

                final title = data['title']?.toString() ?? 'PayFlow Notification';
                final body = data['body']?.toString() ?? '';
                final type = data['type']?.toString() ?? 'transfer';
                final category = type == 'promotions'
                    ? NotificationCategory.promotions
                    : (type == 'security'
                        ? NotificationCategory.security
                        : NotificationCategory.transactions);

                // 1. Show floating in-app banner
                showInAppBanner(title: title, body: body, payload: data);

                // 2. Broadcast to onNotificationReceived stream (triggers refreshWallet() etc.)
                final item = NotificationItem(
                  id: docId,
                  title: title,
                  body: body,
                  category: category,
                  timestamp: DateTime.tryParse(data['createdAt']?.toString() ?? '') ?? DateTime.now(),
                  isRead: data['read'] == true,
                  payload: data,
                );
                _notificationStreamController.add(item);
              }
            }
          },
          onError: (err) {
            debugPrint('[NotificationService] Firestore notification stream notice for user $id: $err');
          },
        );
        _firestoreSubscriptions.add(sub);
      } catch (e) {
        debugPrint('[NotificationService] Could not bind Firestore stream for user $id: $e');
      }
    }
  }

  /// Alias for [startRealtimeNotifications]
  void startFirestoreNotificationStream(String currentUserId) =>
      startRealtimeNotifications(currentUserId);

  /// Cancels active Firestore notification subscriptions.
  void stopRealtimeNotifications() {
    for (final sub in _firestoreSubscriptions) {
      try {
        sub.cancel();
      } catch (_) {}
    }
    _firestoreSubscriptions.clear();
    _activeUserId = null;
  }

  /// Alias for [stopRealtimeNotifications]
  void stopFirestoreNotificationStream() => stopRealtimeNotifications();

  /// Displays a local system notification & broadcasts event to NotificationCenter
  Future<NotificationItem> showNotification({
    required String title,
    required String body,
    required NotificationCategory category,
    Map<String, dynamic>? payload,
  }) async {
    final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    final item = NotificationItem(
      id: 'NOTIF-$notificationId',
      title: title,
      body: body,
      category: category,
      timestamp: DateTime.now(),
      isRead: false,
      payload: payload,
    );

    // Guard: Check whether plugin is initialized or running on web before attempting to show local notifications
    if (kIsWeb || !_isInitialized) {
      debugPrint(
        '[NotificationService] Notification display skipped: ${kIsWeb ? "web environment" : "plugin uninitialized (headless/test environment)"}.',
      );
      _notificationStreamController.add(item);
      return item;
    }

    // Android notification details based on category
    final androidDetails = AndroidNotificationDetails(
      category.channelId,
      category.channelName,
      importance: category == NotificationCategory.promotions
          ? Importance.defaultImportance
          : Importance.high,
      priority: category == NotificationCategory.promotions
          ? Priority.defaultPriority
          : Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _localNotifications.show(
        notificationId,
        title,
        body,
        details,
        payload: jsonEncode(item.toJson()),
      );
    } catch (e) {
      if (e.toString().contains('LateInitializationError') ||
          e.toString().contains('not been initialized')) {
        debugPrint(
          '[NotificationService] Local notifications platform uninitialized: skipping display.',
        );
      } else {
        debugPrint('[NotificationService] Local notification display fallback: $e');
      }
    }

    _notificationStreamController.add(item);
    return item;
  }

  void dispose() {
    stopRealtimeNotifications();
    _notificationStreamController.close();
  }
}
