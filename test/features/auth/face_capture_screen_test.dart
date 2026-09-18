import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payflow/features/auth/views/face_capture_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget createTestApp(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('FaceCaptureScreen Automated Test Suite', () {
    testWidgets('1. Renders checklist guidance and terms checkbox on initial load', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(const FaceCaptureScreen()));
      await tester.pumpAndSettle();

      expect(find.text("Let's do your capturing"), findsOneWidget);
      expect(find.text('Good lighting'), findsOneWidget);
      expect(find.text('Look straight'), findsOneWidget);
      expect(find.text('Remove accessories'), findsOneWidget);
      expect(
        find.text('I agree to the Terms and Conditions and consent to facial biometric verification.'),
        findsOneWidget,
      );
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('2. Continue button requires terms checkbox to be toggled', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(const FaceCaptureScreen()));
      await tester.pumpAndSettle();

      // Tap Continue before checking terms -> should remain on checklist view
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text("Let's do your capturing"), findsOneWidget);
      expect(find.text('Face Capturing'), findsNothing);

      // Tap checkbox to agree to terms
      final checkbox = find.byType(Checkbox);
      expect(checkbox, findsOneWidget);
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();

      // Tap Continue now that terms are accepted -> should transition to capturing view
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Face Capturing'), findsOneWidget);
      expect(find.text('Align your face inside the circle and hold still.'), findsOneWidget);
      expect(find.text('Capture Photo'), findsOneWidget);
    });

    testWidgets('3. Capture triggers simulated liveness and reveals success state with Add BVN/NIN', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(const FaceCaptureScreen()));
      await tester.pumpAndSettle();

      // Accept terms and proceed to capture
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Trigger capture
      expect(find.text('Capture Photo'), findsOneWidget);
      await tester.tap(find.text('Capture Photo'));
      await tester.pump(); // Start async delay

      // Pump 1300ms to complete liveness simulation
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();

      // Check success state
      expect(find.text('Face capturing successful'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.text('Add BVN/NIN'), findsOneWidget);
    });
  });
}
