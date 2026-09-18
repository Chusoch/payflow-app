import 'package:flutter_test/flutter_test.dart';
import 'package:payflow/features/kyc/models/kyc_state.dart';
import 'package:payflow/features/kyc/models/kyc_tier.dart';
import 'package:payflow/features/kyc/repositories/mock_kyc_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MockKycRepository Unit Tests', () {
    late MockKycRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repository = MockKycRepository();
      await repository.init();
    });

    test('Initial loaded state returns default Tier 1 unverified state', () {
      final state = repository.loadKycState();
      expect(state.tierLevel, KycTierLevel.tier1);
      expect(state.status, KycStatus.notStarted);
      expect(state.isBvnVerified, false);
      expect(state.isNinVerified, false);
    });

    test('verifyBvn succeeds with 11 digits and fails with 00000000000', () async {
      final valid = await repository.verifyBvn('22345678901');
      expect(valid, isTrue);

      final invalidDigits = await repository.verifyBvn('12345');
      expect(invalidDigits, isFalse);

      final mockFail = await repository.verifyBvn('00000000000');
      expect(mockFail, isFalse);
    });

    test('verifyNin succeeds with 11 digits and fails with 00000000000', () async {
      final valid = await repository.verifyNin('12345678901');
      expect(valid, isTrue);

      final invalidDigits = await repository.verifyNin('999');
      expect(invalidDigits, isFalse);

      final mockFail = await repository.verifyNin('00000000000');
      expect(mockFail, isFalse);
    });

    test('submitKyc upgrades tier and persists status', () async {
      const state = KycState(
        firstName: 'Chuma',
        lastName: 'Ugo',
        addressLine: '12 Main St',
        city: 'Lagos',
        stateName: 'Lagos',
        country: 'Nigeria',
        isBvnVerified: true,
        isNinVerified: true,
        isLivenessVerified: true,
        isDocUploaded: true,
      );

      final newTier = await repository.submitKyc(state);
      expect(newTier, KycTierLevel.tier3);

      final reloadedState = repository.loadKycState();
      expect(reloadedState.status, KycStatus.verified);
      expect(reloadedState.tierLevel, KycTierLevel.tier3);
    });
  });
}
