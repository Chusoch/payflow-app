import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payflow/features/home/views/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createWidgetUnderTest() {
    return const ProviderScope(
      child: MaterialApp(
        home: HomeScreen(),
      ),
    );
  }

  group('HomeScreen Refinement Widget Tests', () {
    testWidgets('Renders greeting, user name and account number', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Hi, User'), findsOneWidget);
      expect(find.textContaining('Acc: --'), findsOneWidget);
    });

    testWidgets('Toggles wallet balance visibility when eye icon is tapped', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('₦245850.75'), findsOneWidget);

      final visibilityToggle = find.byIcon(Icons.visibility_outlined);
      expect(visibilityToggle, findsOneWidget);
      await tester.tap(visibilityToggle);
      await tester.pumpAndSettle();

      expect(find.text('₦245850.75'), findsNothing);
      expect(find.text('₦ • • • • • • •'), findsOneWidget);
    });

    testWidgets('Renders Primary Money Actions (To PayFlow, To Bank, Add Money)', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('To PayFlow'), findsOneWidget);
      expect(find.text('To Bank'), findsOneWidget);
      expect(find.text('Add Money'), findsWidgets);
      expect(find.byKey(const Key('add_money_button')), findsOneWidget);
    });

    testWidgets('Renders Services entry items from ServicesViewModel', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Services'), findsOneWidget);
      expect(find.text('Airtime'), findsOneWidget);
      expect(find.text('Mobile Data'), findsOneWidget);
      expect(find.text('Electricity'), findsOneWidget);
    });

    testWidgets('Renders Promo Banner Carousel and Transaction Ticker', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Zero Fee Bank Transfers'), findsOneWidget);
      expect(find.text('Transactions'), findsOneWidget);
      expect(find.text('See All'), findsWidgets);
    });

    testWidgets('Renders interactive bell icon with Badge for unread notifications', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final bellIcon = find.byIcon(Icons.notifications_none_rounded);
      expect(bellIcon, findsOneWidget);
      expect(find.byType(Badge), findsOneWidget);
    });
  });
}
