import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:payflow/core/widgets/payflow_button.dart';
import 'package:payflow/features/auth/views/bvn_nin_verification_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget createTestRouterApp() {
  final router = GoRouter(
    initialLocation: '/bvn-nin-verification',
    routes: [
      GoRoute(
        path: '/bvn-nin-verification',
        builder: (context, state) => const BvnNinVerificationScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Login Screen Mock')),
        ),
      ),
      GoRoute(
        path: '/phone-entry',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Phone Entry Screen Mock')),
        ),
      ),
    ],
  );

  return ProviderScope(
    child: MaterialApp.router(
      routerConfig: router,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('BvnNinVerificationScreen Automated Test Suite', () {
    testWidgets('1. Top tab selector switches between BVN and NIN, updating title & hints', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestRouterApp());
      await tester.pumpAndSettle();

      // Initial state is BVN
      expect(find.text('Please provide your BVN'), findsOneWidget);
      expect(find.text('Bank Verification Number (BVN)'), findsOneWidget);
      expect(find.text('Enter 11-digit BVN'), findsOneWidget);

      // Switch to NIN tab
      final ninTab = find.byKey(const Key('nin_tab'));
      expect(ninTab, findsOneWidget);
      await tester.tap(ninTab);
      await tester.pumpAndSettle();

      // Title & hints updated to NIN
      expect(find.text('Please provide your NIN'), findsOneWidget);
      expect(find.text('National Identity Number (NIN)'), findsOneWidget);
      expect(find.text('Enter 11-digit NIN'), findsOneWidget);

      // Switch back to BVN tab
      final bvnTab = find.byKey(const Key('bvn_tab'));
      await tester.tap(bvnTab);
      await tester.pumpAndSettle();

      expect(find.text('Please provide your BVN'), findsOneWidget);
    });

    testWidgets('2. 11-digit input field validation gates Continue button state', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestRouterApp());
      await tester.pumpAndSettle();

      final continueButtonFinder = find.byKey(const Key('continue_verification_button'));
      expect(continueButtonFinder, findsOneWidget);

      // Initially empty -> Continue button disabled
      PayFlowButton buttonWidget = tester.widget<PayFlowButton>(continueButtonFinder);
      expect(buttonWidget.onPressed, isNull);
      expect(find.text('0 / 11'), findsOneWidget);

      // Enter 5 digits -> Still disabled
      final inputField = find.byKey(const Key('identifier_input_field'));
      await tester.enterText(inputField, '12345');
      await tester.pumpAndSettle();

      buttonWidget = tester.widget<PayFlowButton>(continueButtonFinder);
      expect(buttonWidget.onPressed, isNull);
      expect(find.text('5 / 11'), findsOneWidget);

      // Enter 11 digits -> Enabled
      await tester.enterText(inputField, '12345678901');
      await tester.pumpAndSettle();

      buttonWidget = tester.widget<PayFlowButton>(continueButtonFinder);
      expect(buttonWidget.onPressed, isNotNull);
      expect(find.text('11 / 11'), findsOneWidget);
    });

    testWidgets('3. Pre-seeded existing customer triggers "Welcome back!" modal bottom sheet', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestRouterApp());
      await tester.pumpAndSettle();

      // Enter pre-seeded existing customer number
      final inputField = find.byKey(const Key('identifier_input_field'));
      await tester.enterText(inputField, '22222222222');
      await tester.pumpAndSettle();

      // Tap Continue
      final continueButton = find.byKey(const Key('continue_verification_button'));
      await tester.tap(continueButton);
      await tester.pump();
      await tester.pumpAndSettle();

      // Existing Customer Modal elements rendered
      expect(find.text('Welcome back!'), findsOneWidget);
      expect(
        find.text("You're an existing customer. Please click proceed to login to your account."),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
      expect(find.byKey(const Key('go_to_login_button')), findsOneWidget);
    });

    testWidgets('4. Tapping "Go to login" on modal navigates to /login', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestRouterApp());
      await tester.pumpAndSettle();

      // Open existing customer modal
      final inputField = find.byKey(const Key('identifier_input_field'));
      await tester.enterText(inputField, '22222222222');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('continue_verification_button')));
      await tester.pumpAndSettle();

      // Tap "Go to login"
      final goToLoginBtn = find.byKey(const Key('go_to_login_button'));
      expect(goToLoginBtn, findsOneWidget);
      await tester.tap(goToLoginBtn);
      await tester.pumpAndSettle();

      // Successfully routed to /login
      expect(find.text('Login Screen Mock'), findsOneWidget);
    });

    testWidgets('5. New customer with valid 11 digits presents Identity Confirmation Card and proceeds to /phone-entry on confirmation', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestRouterApp());
      await tester.pumpAndSettle();

      // Enter valid new customer number (ends in 1 -> Amaka Nnamdi persona)
      final inputField = find.byKey(const Key('identifier_input_field'));
      await tester.enterText(inputField, '12345678901');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('continue_verification_button')));
      await tester.pump();
      await tester.pumpAndSettle();

      // Identity Confirmation Card is presented
      expect(find.text('Confirm Your Identity'), findsOneWidget);
      expect(find.text('Amaka Nnamdi'), findsOneWidget);
      expect(find.text('23-Aug-2001'), findsOneWidget);
      expect(find.text('Female'), findsOneWidget);
      expect(find.text('Verified via Identity Database'), findsOneWidget);
      expect(find.byKey(const Key('confirm_identity_button')), findsOneWidget);
      expect(find.byKey(const Key('reject_identity_button')), findsOneWidget);

      // Tap Primary CTA: "Yes, This Is Me"
      await tester.tap(find.byKey(const Key('confirm_identity_button')));
      await tester.pumpAndSettle();

      // Successfully routed to /phone-entry
      expect(find.text('Phone Entry Screen Mock'), findsOneWidget);
    });

    testWidgets('6. Non-existent number (00000000000) displays error message', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestRouterApp());
      await tester.pumpAndSettle();

      final inputField = find.byKey(const Key('identifier_input_field'));
      await tester.enterText(inputField, '00000000000');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('continue_verification_button')));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('No identity record found for this number'), findsOneWidget);
    });

    testWidgets('7. Tapping "Not My Details" dismisses confirmation modal and clears 11-digit input', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestRouterApp());
      await tester.pumpAndSettle();

      final inputField = find.byKey(const Key('identifier_input_field'));
      await tester.enterText(inputField, '12345678901');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('continue_verification_button')));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Your Identity'), findsOneWidget);

      // Tap "Not My Details"
      final rejectBtn = find.byKey(const Key('reject_identity_button'));
      expect(rejectBtn, findsOneWidget);
      await tester.tap(rejectBtn);
      await tester.pumpAndSettle();

      // Modal is dismissed and input is reset
      expect(find.text('Confirm Your Identity'), findsNothing);
      expect(find.text('0 / 11'), findsOneWidget);
      expect(find.text('Phone Entry Screen Mock'), findsNothing);
    });

    testWidgets('8. Identity Confirmation Card displays dynamic persona for input ending in 3 (Babajide Adeyemi)', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestRouterApp());
      await tester.pumpAndSettle();

      final inputField = find.byKey(const Key('identifier_input_field'));
      await tester.enterText(inputField, '12345678903');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('continue_verification_button')));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Your Identity'), findsOneWidget);
      expect(find.text('Babajide Adeyemi'), findsOneWidget);
      expect(find.text('05-Nov-1995'), findsOneWidget);
      expect(find.text('Male'), findsOneWidget);
    });
  });
}
