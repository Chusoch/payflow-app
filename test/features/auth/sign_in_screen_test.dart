import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:payflow/features/auth/views/sign_in_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget createSignInTestApp({
  List<Override> overrides = const [],
  String initialLocation = '/sign-in',
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/face-capture',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Face Capture Screen Mock')),
        ),
      ),
      GoRoute(
        path: '/otp-verification',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('OTP Verification Screen Mock')),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Onboarding Screen Mock')),
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

  group('Universal Sign-In Screen Automated Test Suite', () {
    testWidgets('1. Renders clean light-mode interface with adaptive input and CTAs', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createSignInTestApp());
      await tester.pumpAndSettle();

      // Heading and Subtitle
      expect(find.text('Sign In to PayFlow'), findsOneWidget);
      expect(find.text('Enter your registered email address or phone number to continue.'), findsOneWidget);

      // Adaptive identifier field
      expect(find.text('Email or Phone Number'), findsOneWidget);
      expect(find.byKey(const Key('sign_in_identifier_input')), findsOneWidget);

      // Primary CTA: Continue
      expect(find.byKey(const Key('sign_in_continue_button')), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);

      // Secondary Link: Create Account
      expect(find.text('New to PayFlow?'), findsOneWidget);
      expect(find.byKey(const Key('create_account_button')), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
    });

    testWidgets('2. Empty identifier displays validation error on Continue', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createSignInTestApp());
      await tester.pumpAndSettle();

      final continueBtn = find.byKey(const Key('sign_in_continue_button'));
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email or phone number.'), findsOneWidget);
    });

    testWidgets('3. Create Account navigates to /face-capture', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createSignInTestApp());
      await tester.pumpAndSettle();

      final createAccountBtn = find.byKey(const Key('create_account_button'));
      await tester.tap(createAccountBtn);
      await tester.pumpAndSettle();

      expect(find.text('Face Capture Screen Mock'), findsOneWidget);
    });

    testWidgets('4. Valid phone number submits and routes to OTP verification', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createSignInTestApp());
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('sign_in_identifier_input')), '08012345678');
      await tester.pumpAndSettle();

      final continueBtn = find.byKey(const Key('sign_in_continue_button'));
      await tester.tap(continueBtn);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.text('OTP Verification Screen Mock'), findsOneWidget);
    });
  });
}
