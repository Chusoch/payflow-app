import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/notifications/notification_service.dart';
import 'core/router/app_router.dart';
import 'core/services/sentry_scrubber.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/models/auth_state.dart';
import 'features/auth/view_models/auth_view_model.dart';
import 'features/profile/view_models/profile_view_model.dart';
import 'features/wallet/view_models/wallet_view_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Defensive initialization of NotificationService with try-catch and timeout
  // so any platform channel or network hang never blocks runApp().
  try {
    await NotificationService()
        .initialize()
        .timeout(const Duration(seconds: 3), onTimeout: () {
      debugPrint('[Main] NotificationService init timed out after 3s. Continuing to runApp.');
    });
  } catch (e) {
    debugPrint('[Main] NotificationService init notice: $e. Continuing to runApp.');
  }

  const sentryDsn = String.fromEnvironment('SENTRY_DSN');

  if (sentryDsn.isNotEmpty && !kIsWeb) {
    try {
      await SentryFlutter.init(
        (options) {
          options.dsn = sentryDsn;
          options.tracesSampleRate = 0.2;
          options.beforeSend = sentryBeforeSendScrubber;
        },
        appRunner: () => runApp(
          const ProviderScope(
            child: PayFlowApp(),
          ),
        ),
      );
      return;
    } catch (e) {
      debugPrint('[Main] SentryFlutter init notice: $e. Falling back to runApp.');
    }
  }

  runApp(
    const ProviderScope(
      child: PayFlowApp(),
    ),
  );
}

class PayFlowApp extends ConsumerWidget {
  const PayFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileViewModelProvider);
    final router = ref.watch(appRouterProvider);

    // Automatically manage real-time Firestore notification stream & wallet balance based on auth state
    ref.listen<AuthState>(authViewModelProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated) {
        final phone = next.phoneNumber;
        if (phone != null && phone.isNotEmpty) {
          NotificationService().startRealtimeNotifications(phone);
        }
        ref.read(walletViewModelProvider.notifier).fetchWalletData();
      } else if (next.status == AuthStatus.unauthenticated) {
        NotificationService().stopRealtimeNotifications();
      }
    });

    final authState = ref.watch(authViewModelProvider);
    if (authState.status == AuthStatus.authenticated &&
        authState.phoneNumber != null &&
        authState.phoneNumber!.isNotEmpty) {
      NotificationService().startRealtimeNotifications(authState.phoneNumber!);
    }

    return MaterialApp.router(
      title: 'PayFlow Fintech',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(context),
      darkTheme: AppTheme.darkTheme(context),
      themeMode: profileState.themeMode == ThemeMode.system
          ? ThemeMode.light
          : profileState.themeMode,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      routerConfig: router,
    );
  }
}
