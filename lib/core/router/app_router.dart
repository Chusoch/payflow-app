import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/models/auth_state.dart';
import '../../features/auth/view_models/auth_view_model.dart';
import '../../features/auth/views/biometric_setup_screen.dart';
import '../../features/auth/views/bvn_nin_verification_screen.dart';
import '../../features/auth/views/confirm_pin_screen.dart';
import '../../features/auth/views/create_pin_screen.dart';
import '../../features/auth/views/face_capture_screen.dart';
import '../../features/auth/views/login_screen.dart';
import '../../features/auth/views/onboarding_screen.dart';
import '../../features/auth/views/otp_verification_screen.dart';
import '../../features/auth/views/phone_entry_screen.dart';
import '../../features/auth/views/pin_entry_screen.dart';
import '../../features/auth/views/profile_setup_screen.dart';
import '../../features/auth/views/sign_in_screen.dart';
import '../../features/auth/views/splash_screen.dart';
import '../../features/home/views/home_screen.dart';
import '../../features/kyc/views/kyc_account_type_screen.dart';
import '../../features/kyc/views/kyc_address_screen.dart';
import '../../features/kyc/views/kyc_document_upload_screen.dart';
import '../../features/kyc/views/kyc_identity_screen.dart';
import '../../features/kyc/views/kyc_intro_screen.dart';
import '../../features/kyc/views/kyc_liveness_screen.dart';
import '../../features/kyc/views/kyc_personal_info_screen.dart';
import '../../features/kyc/views/kyc_review_screen.dart';
import '../../features/kyc/views/kyc_status_screen.dart';
import '../../features/notifications/views/notification_center_screen.dart';
import '../../features/notifications/views/notification_preferences_screen.dart';
import '../../features/profile/views/profile_screen.dart';
import '../../features/services/views/services_screen.dart';
import '../../features/transfer/views/transfer_screen.dart';
import '../../features/wallet/views/wallet_screen.dart';
import 'scaffold_with_navbar.dart';

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>(debugLabel: 'rootScaffoldMessenger');

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: _RiverpodListenable(ref, authViewModelProvider),
    redirect: (context, state) {
      final authState = ref.read(authViewModelProvider);
      final location = state.uri.toString();

      final isAuthRoute = location == '/splash' ||
          location == '/onboarding' ||
          location == '/face-capture' ||
          location == '/bvn-nin-verification' ||
          location == '/phone-entry' ||
          location == '/otp-verification' ||
          location == '/create-pin' ||
          location == '/confirm-pin' ||
          location == '/profile-setup' ||
          location == '/biometric-setup' ||
          location == '/login' ||
          location == '/sign-in' ||
          location == '/pin-entry';

      if (authState.isLoading && location != '/splash') {
        return null;
      }

      switch (authState.status) {
        case AuthStatus.initial:
          return null;

        case AuthStatus.onboardingRequired:
          if (location != '/onboarding' && location != '/splash') {
            return '/onboarding';
          }
          return null;

        case AuthStatus.unauthenticated:
          if (!isAuthRoute) {
            return '/login';
          }
          return null;

        case AuthStatus.awaitingOtp:
          if (location != '/otp-verification' && location != '/splash') {
            return '/otp-verification';
          }
          return null;

        case AuthStatus.awaitingPinSetup:
          if (location != '/create-pin' && location != '/splash') {
            return '/create-pin';
          }
          return null;

        case AuthStatus.awaitingPinConfirm:
          if (location != '/confirm-pin' && location != '/splash') {
            return '/confirm-pin';
          }
          return null;

        case AuthStatus.awaitingProfileSetup:
          if (location != '/profile-setup' && location != '/splash') {
            return '/profile-setup';
          }
          return null;

        case AuthStatus.awaitingPinLogin:
          if (location != '/pin-entry' && location != '/splash') {
            return '/pin-entry';
          }
          return null;

        case AuthStatus.awaitingBiometrics:
          if (location != '/biometric-setup' && location != '/splash') {
            return '/biometric-setup';
          }
          return null;

        case AuthStatus.authenticated:
          if (isAuthRoute && location != '/splash') {
            return '/home';
          }
          return null;
      }
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/face-capture',
        builder: (context, state) => const FaceCaptureScreen(),
      ),
      GoRoute(
        path: '/bvn-nin-verification',
        builder: (context, state) => const BvnNinVerificationScreen(),
      ),
      GoRoute(
        path: '/phone-entry',
        builder: (context, state) => const PhoneEntryScreen(),
      ),
      GoRoute(
        path: '/otp-verification',
        builder: (context, state) => const OtpVerificationScreen(),
      ),
      GoRoute(
        path: '/create-pin',
        builder: (context, state) => const CreatePinScreen(),
      ),
      GoRoute(
        path: '/confirm-pin',
        builder: (context, state) => const ConfirmPinScreen(),
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/biometric-setup',
        builder: (context, state) => const BiometricSetupScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/pin-entry',
        builder: (context, state) => const PinEntryScreen(),
      ),

      // KYC Flow Routes
      GoRoute(
        path: '/kyc/intro',
        builder: (context, state) => const KycIntroScreen(),
      ),
      GoRoute(
        path: '/kyc/account-type',
        builder: (context, state) => const KycAccountTypeScreen(),
      ),
      GoRoute(
        path: '/kyc/personal-info',
        builder: (context, state) => const KycPersonalInfoScreen(),
      ),
      GoRoute(
        path: '/kyc/address',
        builder: (context, state) => const KycAddressScreen(),
      ),
      GoRoute(
        path: '/kyc/identity',
        builder: (context, state) => const KycIdentityScreen(),
      ),
      GoRoute(
        path: '/kyc/liveness',
        builder: (context, state) => const KycLivenessScreen(),
      ),
      GoRoute(
        path: '/kyc/documents',
        builder: (context, state) => const KycDocumentUploadScreen(),
      ),
      GoRoute(
        path: '/kyc/review',
        builder: (context, state) => const KycReviewScreen(),
      ),
      GoRoute(
        path: '/kyc/status',
        builder: (context, state) => const KycStatusScreen(),
      ),

      // Notification Center & Preferences Routes
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationCenterScreen(),
      ),
      GoRoute(
        path: '/notifications/preferences',
        builder: (context, state) => const NotificationPreferencesScreen(),
      ),

      // Main App Navigation Shell
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          // Tab 1: Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),

          // Tab 2: Wallet
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/wallet',
                builder: (context, state) => const WalletScreen(),
              ),
            ],
          ),

          // Tab 3: Transfer
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/transfer',
                builder: (context, state) => const TransferScreen(),
              ),
            ],
          ),

          // Tab 4: Services
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/services',
                builder: (context, state) => const ServicesScreen(),
              ),
            ],
          ),

          // Tab 5: Profile & Settings
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

// Helper Listenable adapter for Riverpod state changes
class _RiverpodListenable extends ChangeNotifier {
  _RiverpodListenable(Ref ref, ProviderListenable provider) {
    ref.listen(provider, (previous, next) => notifyListeners());
  }
}
