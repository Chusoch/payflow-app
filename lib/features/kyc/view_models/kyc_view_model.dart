import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/kyc_state.dart';
import '../models/kyc_tier.dart';
import '../repositories/kyc_repository.dart';
import '../repositories/mock_kyc_repository.dart';

final kycRepositoryProvider = Provider<KycRepository>((ref) {
  return MockKycRepository();
});

class KycViewModel extends StateNotifier<KycState> {
  final KycRepository _repository;

  KycViewModel(this._repository) : super(const KycState()) {
    init();
  }

  Future<void> init() async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.init();
      final loadedState = _repository.loadKycState();
      state = loadedState.copyWith(isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  void setAccountType(AccountType type) {
    state = state.copyWith(accountType: type);
    _repository.saveKycState(state);
  }

  void updatePersonalInfo({
    String? firstName,
    String? lastName,
    String? dob,
    String? gender,
    String? nationality,
  }) {
    state = state.copyWith(
      firstName: firstName ?? state.firstName,
      lastName: lastName ?? state.lastName,
      dob: dob ?? state.dob,
      gender: gender ?? state.gender,
      nationality: nationality ?? state.nationality,
      errorMessage: null,
    );
    _repository.saveKycState(state);
  }

  void updateBusinessInfo({
    String? businessName,
    String? businessType,
    String? registrationNumber,
    String? businessEmail,
  }) {
    state = state.copyWith(
      businessName: businessName ?? state.businessName,
      businessType: businessType ?? state.businessType,
      registrationNumber: registrationNumber ?? state.registrationNumber,
      businessEmail: businessEmail ?? state.businessEmail,
      errorMessage: null,
    );
    _repository.saveKycState(state);
  }

  void updateAddress({
    String? addressLine,
    String? city,
    String? stateName,
    String? country,
  }) {
    state = state.copyWith(
      addressLine: addressLine ?? state.addressLine,
      city: city ?? state.city,
      stateName: stateName ?? state.stateName,
      country: country ?? state.country,
      errorMessage: null,
    );
    _repository.saveKycState(state);
  }

  Future<bool> verifyBvn(String bvnInput) async {
    final cleanBvn = bvnInput.trim();
    if (cleanBvn.isEmpty || cleanBvn.length != 11 || !RegExp(r'^\d+$').hasMatch(cleanBvn)) {
      state = state.copyWith(
        bvn: cleanBvn,
        isBvnVerified: false,
        bvnError: 'BVN must be an 11-digit numeric code.',
      );
      return false;
    }

    state = state.copyWith(
      bvn: cleanBvn,
      isLoading: true,
      bvnError: null,
    );

    try {
      final success = await _repository.verifyBvn(cleanBvn);
      if (success) {
        state = state.copyWith(
          isLoading: false,
          isBvnVerified: true,
          bvnError: null,
        );
        _repository.saveKycState(state);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          isBvnVerified: false,
          bvnError: 'BVN verification failed. (Tip: Do not use 00000000000).',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isBvnVerified: false,
        bvnError: 'BVN service unavailable. Please retry.',
      );
      return false;
    }
  }

  Future<bool> verifyNin(String ninInput) async {
    final cleanNin = ninInput.trim();
    if (cleanNin.isEmpty || cleanNin.length != 11 || !RegExp(r'^\d+$').hasMatch(cleanNin)) {
      state = state.copyWith(
        nin: cleanNin,
        isNinVerified: false,
        ninError: 'NIN must be an 11-digit numeric code.',
      );
      return false;
    }

    state = state.copyWith(
      nin: cleanNin,
      isLoading: true,
      ninError: null,
    );

    try {
      final success = await _repository.verifyNin(cleanNin);
      if (success) {
        state = state.copyWith(
          isLoading: false,
          isNinVerified: true,
          ninError: null,
        );
        _repository.saveKycState(state);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          isNinVerified: false,
          ninError: 'NIN verification failed. (Tip: Do not use 00000000000).',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isNinVerified: false,
        ninError: 'NIN service unavailable. Please retry.',
      );
      return false;
    }
  }

  Future<bool> captureLiveness({String? imagePath}) async {
    state = state.copyWith(
      isLoading: true,
      livenessError: null,
    );

    final path = imagePath ?? 'mock_selfie_liveness_captured.png';
    try {
      final success = await _repository.verifyLiveness(path);
      if (success) {
        state = state.copyWith(
          isLoading: false,
          isLivenessVerified: true,
          livenessImagePath: path,
          livenessError: null,
        );
        _repository.saveKycState(state);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          isLivenessVerified: false,
          livenessError: 'Liveness verification failed. Ensure clear lighting.',
        );
        return false;
      }
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        isLivenessVerified: false,
        livenessError: 'Liveness capture error. Please retry.',
      );
      return false;
    }
  }

  void selectDocType(String docType) {
    state = state.copyWith(selectedDocType: docType);
    _repository.saveKycState(state);
  }

  Future<bool> uploadDocument({
    String? docPath,
    String? fileName,
    String? fileSize,
  }) async {
    state = state.copyWith(
      isLoading: true,
      docError: null,
    );

    final name = fileName ?? 'identity_document.pdf';
    final size = fileSize ?? '1.2 MB';
    final path = docPath ?? 'mock_identity_document_${state.selectedDocType.replaceAll(" ", "_")}.pdf';
    try {
      final success = await _repository.uploadDocument(state.selectedDocType, path);
      if (success) {
        state = state.copyWith(
          isLoading: false,
          isDocUploaded: true,
          docPath: path,
          docFileName: name,
          docFileSize: size,
          docError: null,
        );
        _repository.saveKycState(state);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          isDocUploaded: false,
          docError: 'Document upload failed. File must be PNG, JPG, or PDF.',
        );
        return false;
      }
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        isDocUploaded: false,
        docError: 'Failed to upload document. Please try again.',
      );
      return false;
    }
  }

  void removeDocument() {
    state = state.copyWith(
      isDocUploaded: false,
      docPath: null,
      docFileName: null,
      docFileSize: null,
      docError: null,
    );
    _repository.saveKycState(state);
  }

  void setStepIndex(int index) {
    state = state.copyWith(currentStepIndex: index);
  }

  void nextStep() {
    state = state.copyWith(currentStepIndex: state.currentStepIndex + 1);
  }

  void previousStep() {
    if (state.currentStepIndex > 0) {
      state = state.copyWith(currentStepIndex: state.currentStepIndex - 1);
    }
  }

  Future<bool> submitKyc() async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      status: KycStatus.pending,
    );

    try {
      final newTier = await _repository.submitKyc(state);
      state = state.copyWith(
        isLoading: false,
        status: KycStatus.verified,
        tierLevel: newTier,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        status: KycStatus.failed,
        errorMessage: 'KYC submission failed. Please try again.',
      );
      return false;
    }
  }

  Future<void> resetKyc() async {
    await _repository.resetKyc();
    state = const KycState();
  }
}

final kycViewModelProvider =
    StateNotifierProvider<KycViewModel, KycState>((ref) {
  final repository = ref.watch(kycRepositoryProvider);
  return KycViewModel(repository);
});
