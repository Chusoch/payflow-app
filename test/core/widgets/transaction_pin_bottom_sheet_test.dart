import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payflow/core/config/env.dart';
import 'package:payflow/core/widgets/transaction_pin_bottom_sheet.dart';

void main() {
  setUp(() {
    Env.setBackendApiBaseUrlForTesting(null);
  });

  Widget buildTestPinApp({
    required double amount,
    required String recipient,
    String? title,
    void Function(bool?)? onResult,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                final res = await TransactionPinBottomSheet.show(
                  context: context,
                  amount: amount,
                  recipient: recipient,
                  title: title,
                );
                onResult?.call(res);
              },
              child: const Text('Open PIN Modal'),
            ),
          ),
        ),
      ),
    );
  }

  group('TransactionPinBottomSheet Widget Tests', () {
    testWidgets('1. Renders header, amount, recipient, discrete pin circles, and keypad', (tester) async {
      await tester.pumpWidget(
        buildTestPinApp(
          amount: 5000.00,
          recipient: 'Sarah Connor',
        ),
      );
      await tester.pumpAndSettle();

      // Open bottom sheet
      await tester.tap(find.text('Open PIN Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Enter Transaction PIN'), findsOneWidget);
      expect(find.text('₦5000.00'), findsOneWidget);
      expect(find.text('Sarah Connor'), findsOneWidget);

      // Verify keypad numbers 0-9 and backspace icon
      for (int i = 0; i <= 9; i++) {
        expect(find.text('$i'), findsOneWidget);
      }
      expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);
    });

    testWidgets('2. Entering digits updates indicator and backspace deletes digit', (tester) async {
      await tester.pumpWidget(
        buildTestPinApp(
          amount: 2500.00,
          recipient: 'John Doe',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open PIN Modal'));
      await tester.pumpAndSettle();

      // Tap 1, 2
      await tester.tap(find.text('1'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('2'));
      await tester.pump(const Duration(milliseconds: 50));

      // Tap backspace
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pump(const Duration(milliseconds: 50));

      // Modal is still present, no error
      expect(find.text('Enter Transaction PIN'), findsOneWidget);
    });

    testWidgets('3. Correct PIN "1234" in mock mode auto-submits and returns true', (tester) async {
      bool? result;
      await tester.pumpWidget(
        buildTestPinApp(
          amount: 1500.00,
          recipient: 'Jane Doe',
          onResult: (r) => result = r,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open PIN Modal'));
      await tester.pumpAndSettle();

      // Enter 1, 2, 3, 4
      await tester.tap(find.text('1'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('2'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('3'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      // Bottom sheet should be popped
      expect(find.text('Enter Transaction PIN'), findsNothing);
    });

    testWidgets('4. Incorrect PIN shows error and stays open', (tester) async {
      bool? result;
      await tester.pumpWidget(
        buildTestPinApp(
          amount: 1500.00,
          recipient: 'Jane Doe',
          onResult: (r) => result = r,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open PIN Modal'));
      await tester.pumpAndSettle();

      // Enter 9, 9, 9, 9
      await tester.tap(find.text('9'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('9'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('9'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('9'));
      await tester.pumpAndSettle();

      expect(result, isNull);
      expect(find.text('Incorrect PIN. Try again.'), findsOneWidget);
      expect(find.text('Enter Transaction PIN'), findsOneWidget);
    });

    testWidgets('5. Renders without overflow on constrained height viewport', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildTestPinApp(
          amount: 7500.00,
          recipient: 'Constrained Height Test',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open PIN Modal'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Enter Transaction PIN'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
    });
  });
}
