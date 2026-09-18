import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:payflow/features/auth/models/auth_state.dart';
import 'package:payflow/features/auth/repositories/auth_repository.dart';
import 'package:payflow/features/auth/view_models/auth_view_model.dart';
import 'package:payflow/features/auth/views/profile_setup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late MockAuthRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = MockAuthRepository();
    await repository.init();
  });

  Widget buildScreen(AuthViewModel viewModel) {
    final router = GoRouter(
      initialLocation: '/profile-setup',
      routes: [
        GoRoute(
          path: '/profile-setup',
          builder: (context, state) => const ProfileSetupScreen(),
        ),
        GoRoute(
          path: '/biometric-setup',
          builder: (context, state) => const Scaffold(body: Text('Biometrics Screen')),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const Scaffold(body: Text('Home Screen')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        authViewModelProvider.overrideWith((ref) => viewModel),
      ],
      child: MaterialApp.router(
        routerConfig: router,
      ),
    );
  }

  group('ProfileSetupScreen Tests', () {
    testWidgets('Renders all fields: full name (required), email (optional), and submit button', (tester) async {
      final viewModel = AuthViewModel(repository);
      await tester.pumpWidget(buildScreen(viewModel));
      await tester.pumpAndSettle();

      expect(find.text('What should we call you?'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Email Address (Optional)'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('Empty full name shows validation error', (tester) async {
      final viewModel = AuthViewModel(repository);
      await tester.pumpWidget(buildScreen(viewModel));
      await tester.pumpAndSettle();

      final button = find.text('Continue');
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.text('Full name is required'), findsOneWidget);
    });

    testWidgets('Entering valid full name and email submits successfully and updates auth state', (tester) async {
      final viewModel = AuthViewModel(repository);
      viewModel.state = viewModel.state.copyWith(
        status: AuthStatus.awaitingProfileSetup,
        phoneNumber: '8123456789',
      );

      await tester.pumpWidget(buildScreen(viewModel));
      await tester.pumpAndSettle();

      // Enter full name and email
      await tester.enterText(find.byType(TextFormField).first, 'Chukwuma Ugobueze');
      await tester.enterText(find.byType(TextFormField).last, 'chuma@payflow.app');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(viewModel.state.fullName, equals('Chukwuma Ugobueze'));
      expect(viewModel.state.email, equals('chuma@payflow.app'));
    });

    testWidgets('Pre-fills legal full name and marks field read-only with Verified badge when KYC verified', (tester) async {
      final viewModel = AuthViewModel(repository);
      viewModel.state = viewModel.state.copyWith(
        status: AuthStatus.awaitingProfileSetup,
        phoneNumber: '8123456789',
        fullName: 'Chukwuma Ugobueze',
        isKycVerified: true,
      );

      await tester.pumpWidget(buildScreen(viewModel));
      await tester.pumpAndSettle();

      expect(find.text('Chukwuma Ugobueze'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.text('Verified via identity database (Locked)'), findsOneWidget);

      final nameTextField = tester.widget<TextField>(find.byType(TextField).first);
      expect(nameTextField.readOnly, isTrue);
    });
  });
}
