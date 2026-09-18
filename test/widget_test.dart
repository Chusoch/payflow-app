import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payflow/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const ProviderScope(
        child: PayFlowApp(),
      ),
    );

    // Verify app renders
    expect(find.byType(PayFlowApp), findsOneWidget);

    // Settle pending initialization timers (e.g. Splash screen delay)
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });
}
