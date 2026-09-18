import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payflow/features/kyc/views/kyc_account_type_screen.dart';
import 'package:payflow/features/kyc/views/kyc_identity_screen.dart';
import 'package:payflow/features/kyc/views/kyc_intro_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createWidgetUnderTest(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('KYC Widget Tests', () {
    testWidgets('KycIntroScreen renders tier options and start CTA', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(const KycIntroScreen()));
      await tester.pumpAndSettle();

      expect(find.text('KYC Verification'), findsOneWidget);
      expect(find.text('Current Verification Tier'), findsOneWidget);
      expect(find.text('Tier 1 — Basic'), findsWidgets);
      expect(find.text('Upgrade Verification Tier'), findsOneWidget);
    });

    testWidgets('KycAccountTypeScreen renders Individual Account and removes Business Account', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(const KycAccountTypeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Individual Account'), findsOneWidget);
      expect(find.text('Business Account'), findsNothing);

      await tester.tap(find.text('Individual Account'));
      await tester.pumpAndSettle();

      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('KycIdentityScreen renders BVN and NIN fields', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(const KycIdentityScreen()));
      await tester.pumpAndSettle();

      expect(find.text('BVN & NIN Verification'), findsOneWidget);
      expect(find.text('Verify BVN'), findsOneWidget);
      expect(find.text('Verify NIN'), findsOneWidget);
    });
  });
}
