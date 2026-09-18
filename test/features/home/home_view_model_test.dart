import 'package:flutter_test/flutter_test.dart';
import 'package:payflow/features/home/view_models/home_view_model.dart';
import 'package:payflow/features/profile/models/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('HomeViewModel Tests', () {
    test('Initial State carries honest fallback user data when unpopulated', () async {
      final viewModel = HomeViewModel();
      await Future.delayed(Duration.zero);

      final state = viewModel.state;
      expect(state.userName, equals('User'));
      expect(state.accountNumber, isEmpty);
      expect(state.balance, equals(245850.75));
      expect(state.isBalanceVisible, isTrue);
      expect(state.recentTransactions.isNotEmpty, isTrue);
    });

    test('updateFromProfile updates user name and account number accurately', () async {
      final viewModel = HomeViewModel();
      viewModel.updateFromProfile(const UserProfile(
        phone: '+2348012345678',
        displayName: 'Chukwuma Ugobueze',
        fullName: 'Chukwuma Ugobueze',
        email: 'chuma@example.com',
      ));

      expect(viewModel.state.userName, equals('Chukwuma Ugobueze'));
      expect(viewModel.state.accountNumber, equals('8012345678'));
    });

    test('toggleBalanceVisibility toggles visibility state', () async {
      final viewModel = HomeViewModel();
      expect(viewModel.state.isBalanceVisible, isTrue);

      viewModel.toggleBalanceVisibility();
      expect(viewModel.state.isBalanceVisible, isFalse);

      viewModel.toggleBalanceVisibility();
      expect(viewModel.state.isBalanceVisible, isTrue);
    });

    test('setBannerIndex updates active banner page index', () async {
      final viewModel = HomeViewModel();
      expect(viewModel.state.currentBannerIndex, equals(0));

      viewModel.setBannerIndex(2);
      expect(viewModel.state.currentBannerIndex, equals(2));
    });
  });
}
