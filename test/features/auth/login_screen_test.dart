import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:payflow/features/auth/views/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget createTestApp({
  List<Override> overrides = const [],
  String initialLocation = '/login',
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Sign In Screen Mock')),
        ),
      ),
      GoRoute(
        path: '/face-capture',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Face Capture Screen Mock')),
        ),
      ),
      GoRoute(
        path: '/phone-entry',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Phone Entry Screen Mock')),
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Home Screen Mock')),
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      routerConfig: router,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('ALAT-Style Returning User Login Screen Automated Test Suite', () {
    testWidgets('1. Personalized "Welcome Back" header renders with avatar badge and name', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({
        'payflow_onboarding_completed': true,
        'payflow_user_fullname': 'Chukwuma Ugobueze',
        'payflow_user_email': 'ugo.chukwuma@gmail.com',
      });

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Avatar badge renders with initials
      expect(find.byKey(const Key('user_avatar_badge')), findsOneWidget);
      expect(find.text('CU'), findsOneWidget);

      // Header greeting renders
      expect(find.text('Welcome Back!'), findsOneWidget);
      expect(find.text('Chukwuma Ugobueze'), findsOneWidget);
    });

    testWidgets('2. Masked identifier pill and switch action work', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({
        'payflow_onboarding_completed': true,
        'payflow_user_fullname': 'Ugo',
        'payflow_user_email': 'ugobueze@gmail.com',
      });

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Masked identifier pill renders
      expect(find.byKey(const Key('account_pill')), findsOneWidget);
      expect(find.text('ugo***@gmail.com'), findsOneWidget);

      // Switch account action button is present
      final switchBtn = find.byKey(const Key('switch_account_button'));
      expect(switchBtn, findsOneWidget);

      // Tap switch account button
      await tester.tap(switchBtn);
      await tester.pumpAndSettle();

      // Navigated directly to /sign-in
      expect(find.text('Sign In Screen Mock'), findsOneWidget);

      // Storage keys purged
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('saved_user_phone'), isNull);
      expect(prefs.getString('saved_user_email'), isNull);
      expect(prefs.getString('saved_user_name'), isNull);
      expect(prefs.getString('payflow_user_fullname'), isNull);
      expect(prefs.getString('payflow_user_email'), isNull);
    });

    testWidgets('3. 4-Digit passcode discrete boxes render and auto-submit on completion', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({
        'payflow_onboarding_completed': true,
        'payflow_user_email': 'ugo.chukwuma@gmail.com',
      });

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Strictly labeled "Enter 4-Digit Passcode" without "Password"
      expect(find.text('Enter 4-Digit Passcode'), findsOneWidget);
      expect(find.textContaining('Password'), findsNothing);

      // 4 discrete boxes exist
      final box0 = find.byKey(const Key('password_pin_input'));
      expect(box0, findsOneWidget);
      expect(find.byKey(const Key('pin_box_1')), findsOneWidget);
      expect(find.byKey(const Key('pin_box_2')), findsOneWidget);
      expect(find.byKey(const Key('pin_box_3')), findsOneWidget);

      // Entering 4 digits into box 0 distributes and auto-submits
      await tester.enterText(box0, '1234');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // Navigated to Home screen on completion
      expect(find.text('Home Screen Mock'), findsOneWidget);
    });

    testWidgets('4. "Sign up" navigates to the registration flow (/face-capture)', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({
        'payflow_onboarding_completed': true,
        'payflow_user_email': 'ugo.chukwuma@gmail.com',
      });

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(find.text("Don't have an account?"), findsOneWidget);
      final signUpBtn = find.byKey(const Key('sign_up_button'));
      expect(signUpBtn, findsOneWidget);

      await tester.tap(signUpBtn);
      await tester.pumpAndSettle();

      // Navigated to face capture registration flow
      expect(find.text('Face Capture Screen Mock'), findsOneWidget);
    });

    testWidgets('5. Biometric trigger invokes authentication', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({
        'payflow_onboarding_completed': true,
        'payflow_user_fullname': 'Chukwuma Ugobueze',
        'payflow_auth_phone': '8123456789',
      });

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final bioBtn = find.byKey(const Key('biometric_login_button'));
      expect(bioBtn, findsOneWidget);

      await tester.tap(bioBtn);
      // Advance virtual time to complete MockAuthRepository fallback delay (500ms)
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // User authenticated and navigated to Home
      expect(find.text('Home Screen Mock'), findsOneWidget);
    });

    testWidgets('6. Quick links button opens quick links bottom sheet', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({
        'payflow_onboarding_completed': true,
        'payflow_user_email': 'ugo.chukwuma@gmail.com',
      });

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final quickLinksBtn = find.byKey(const Key('quick_links_button'));
      expect(quickLinksBtn, findsOneWidget);

      await tester.tap(quickLinksBtn);
      await tester.pumpAndSettle();

      expect(find.text('Quick Links'), findsOneWidget);
      expect(find.text('Customer Support'), findsOneWidget);
      expect(find.text('Find ATM / Branch'), findsOneWidget);
      expect(find.text('Help & FAQ'), findsOneWidget);
    });

    testWidgets('7. Fresh device with no saved user redirects immediately to /sign-in', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({
        'payflow_onboarding_completed': true,
      });

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Redirects immediately to /sign-in without rendering returning user passcode screen
      expect(find.text('Sign In Screen Mock'), findsOneWidget);
      expect(find.text('Enter 4-Digit Passcode'), findsNothing);
    });
  });
}
