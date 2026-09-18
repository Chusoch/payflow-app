import '../models/kyc_state.dart';
import '../models/kyc_tier.dart';

abstract class KycRepository {
  Future<void> init();
  KycState loadKycState();
  Future<void> saveKycState(KycState state);
  Future<bool> verifyBvn(String bvn);
  Future<bool> verifyNin(String nin);
  Future<bool> verifyLiveness(String imagePath);
  Future<bool> uploadDocument(String docType, String docPath);
  Future<KycTierLevel> submitKyc(KycState state);
  Future<void> resetKyc();
}
