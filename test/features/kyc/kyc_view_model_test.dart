import 'package:flutter_test/flutter_test.dart';
import 'package:payflow/features/kyc/models/kyc_tier.dart';
import 'package:payflow/features/kyc/repositories/mock_kyc_repository.dart';
import 'package:payflow/features/kyc/view_models/kyc_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KycViewModel Unit Tests', () {
    late MockKycRepository repository;
    late KycViewModel viewModel;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repository = MockKycRepository();
      await repository.init();
      viewModel = KycViewModel(repository);
      await viewModel.init();
    });

    test('Initial state is unverified Tier 1', () {
      expect(viewModel.state.status, KycStatus.notStarted);
      expect(viewModel.state.tierLevel, KycTierLevel.tier1);
    });

    test('Account type toggle updates state', () {
      viewModel.setAccountType(AccountType.business);
      expect(viewModel.state.accountType, AccountType.business);

      viewModel.setAccountType(AccountType.individual);
      expect(viewModel.state.accountType, AccountType.individual);
    });

    test('Update personal info updates fields', () {
      viewModel.updatePersonalInfo(
        firstName: 'John',
        lastName: 'Doe',
        dob: '1990-01-01',
        nationality: 'Nigeria',
      );

      expect(viewModel.state.firstName, 'John');
      expect(viewModel.state.lastName, 'Doe');
      expect(viewModel.state.isPersonalInfoValid, isTrue);
    });

    test('Verify BVN handles valid and invalid inputs', () async {
      final invalidRes = await viewModel.verifyBvn('123');
      expect(invalidRes, isFalse);
      expect(viewModel.state.isBvnVerified, isFalse);
      expect(viewModel.state.bvnError, isNotNull);

      final validRes = await viewModel.verifyBvn('22345678901');
      expect(validRes, isTrue);
      expect(viewModel.state.isBvnVerified, isTrue);
      expect(viewModel.state.bvnError, isNull);
    });

    test('Verify NIN handles valid and invalid inputs', () async {
      final invalidRes = await viewModel.verifyNin('00000000000');
      expect(invalidRes, isFalse);
      expect(viewModel.state.isNinVerified, isFalse);

      final validRes = await viewModel.verifyNin('12345678901');
      expect(validRes, isTrue);
      expect(viewModel.state.isNinVerified, isTrue);
    });

    test('Capture liveness and upload document update completion flags', () async {
      final livenessRes = await viewModel.captureLiveness();
      expect(livenessRes, isTrue);
      expect(viewModel.state.isLivenessVerified, isTrue);

      final docRes = await viewModel.uploadDocument();
      expect(docRes, isTrue);
      expect(viewModel.state.isDocUploaded, isTrue);
    });
  });
}
