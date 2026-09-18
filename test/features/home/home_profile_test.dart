import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payflow/features/home/views/home_screen.dart';
import 'package:payflow/features/home/view_models/home_view_model.dart';
import 'package:payflow/features/profile/models/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Home Profile & Identity Tests', () {
    testWidgets('1. Displays honest fallback "User" when no profile name is configured', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hi, User'), findsOneWidget);
      expect(find.text('Alex Johnson'), findsNothing);
      expect(find.textContaining('Acc: --'), findsOneWidget);
    });

    testWidgets('2. Displays real user name and account number when profile is updated', (tester) async {
      final container = ProviderContainer();
      final homeViewModel = container.read(homeViewModelProvider.notifier);

      homeViewModel.updateFromProfile(
        const UserProfile(
          phone: '+2348123456789',
          displayName: 'Tunde Bakare',
          fullName: 'Tunde Bakare',
          email: 'tunde@example.com',
        ),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hi, Tunde'), findsOneWidget);
      expect(find.text('Alex Johnson'), findsNothing);
      expect(find.textContaining('Acc: 8123456789'), findsOneWidget);
    });
  });
}
