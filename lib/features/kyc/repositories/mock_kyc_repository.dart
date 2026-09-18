import 'package:shared_preferences/shared_preferences.dart';
import '../models/kyc_state.dart';
import '../models/kyc_tier.dart';
import 'kyc_repository.dart';

class MockKycRepository implements KycRepository {
  static const String _keyAccountType = 'payflow_kyc_account_type';
  static const String _keyFirstName = 'payflow_kyc_first_name';
  static const String _keyLastName = 'payflow_kyc_last_name';
  static const String _keyDob = 'payflow_kyc_dob';
  static const String _keyGender = 'payflow_kyc_gender';
  static const String _keyNationality = 'payflow_kyc_nationality';
  static const String _keyBusinessName = 'payflow_kyc_business_name';
  static const String _keyBusinessType = 'payflow_kyc_business_type';
  static const String _keyRegNumber = 'payflow_kyc_reg_number';
  static const String _keyBusinessEmail = 'payflow_kyc_business_email';
  static const String _keyAddressLine = 'payflow_kyc_address_line';
  static const String _keyCity = 'payflow_kyc_city';
  static const String _keyStateName = 'payflow_kyc_state_name';
  static const String _keyCountry = 'payflow_kyc_country';
  static const String _keyBvn = 'payflow_kyc_bvn';
  static const String _keyIsBvnVerified = 'payflow_kyc_bvn_verified';
  static const String _keyNin = 'payflow_kyc_nin';
  static const String _keyIsNinVerified = 'payflow_kyc_nin_verified';
  static const String _keyIsLivenessVerified = 'payflow_kyc_liveness_verified';
  static const String _keyLivenessImagePath = 'payflow_kyc_liveness_image';
  static const String _keySelectedDocType = 'payflow_kyc_doc_type';
  static const String _keyDocPath = 'payflow_kyc_doc_path';
  static const String _keyDocFileName = 'payflow_kyc_doc_filename';
  static const String _keyDocFileSize = 'payflow_kyc_doc_filesize';
  static const String _keyIsDocUploaded = 'payflow_kyc_doc_uploaded';
  static const String _keyStatus = 'payflow_kyc_status';
  static const String _keyTierLevel = 'payflow_kyc_tier_level';

  SharedPreferences? _prefs;

  @override
  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {
      // Graceful fallback for test or restricted storage environments
    }
  }

  @override
  KycState loadKycState() {
    if (_prefs == null) return const KycState();

    final accountTypeIndex = _prefs?.getInt(_keyAccountType) ?? 0;
    final statusIndex = _prefs?.getInt(_keyStatus) ?? 0;
    final tierIndex = _prefs?.getInt(_keyTierLevel) ?? 0;

    return KycState(
      accountType: AccountType.values[accountTypeIndex.clamp(0, AccountType.values.length - 1)],
      firstName: _prefs?.getString(_keyFirstName) ?? '',
      lastName: _prefs?.getString(_keyLastName) ?? '',
      dob: _prefs?.getString(_keyDob) ?? '',
      gender: _prefs?.getString(_keyGender) ?? 'Male',
      nationality: _prefs?.getString(_keyNationality) ?? 'Nigeria',
      businessName: _prefs?.getString(_keyBusinessName) ?? '',
      businessType: _prefs?.getString(_keyBusinessType) ?? 'Sole Proprietorship',
      registrationNumber: _prefs?.getString(_keyRegNumber) ?? '',
      businessEmail: _prefs?.getString(_keyBusinessEmail) ?? '',
      addressLine: _prefs?.getString(_keyAddressLine) ?? '',
      city: _prefs?.getString(_keyCity) ?? '',
      stateName: _prefs?.getString(_keyStateName) ?? 'Lagos',
      country: _prefs?.getString(_keyCountry) ?? 'Nigeria',
      bvn: _prefs?.getString(_keyBvn) ?? '',
      isBvnVerified: _prefs?.getBool(_keyIsBvnVerified) ?? false,
      nin: _prefs?.getString(_keyNin) ?? '',
      isNinVerified: _prefs?.getBool(_keyIsNinVerified) ?? false,
      isLivenessVerified: _prefs?.getBool(_keyIsLivenessVerified) ?? false,
      livenessImagePath: _prefs?.getString(_keyLivenessImagePath),
      selectedDocType: _prefs?.getString(_keySelectedDocType) ?? 'National Identity Card (NIN Slip)',
      docPath: _prefs?.getString(_keyDocPath),
      docFileName: _prefs?.getString(_keyDocFileName),
      docFileSize: _prefs?.getString(_keyDocFileSize),
      isDocUploaded: _prefs?.getBool(_keyIsDocUploaded) ?? false,
      status: KycStatus.values[statusIndex.clamp(0, KycStatus.values.length - 1)],
      tierLevel: KycTierLevel.values[tierIndex.clamp(0, KycTierLevel.values.length - 1)],
    );
  }

  @override
  Future<void> saveKycState(KycState state) async {
    if (_prefs == null) return;

    await _prefs?.setInt(_keyAccountType, state.accountType.index);
    await _prefs?.setString(_keyFirstName, state.firstName);
    await _prefs?.setString(_keyLastName, state.lastName);
    await _prefs?.setString(_keyDob, state.dob);
    await _prefs?.setString(_keyGender, state.gender);
    await _prefs?.setString(_keyNationality, state.nationality);
    await _prefs?.setString(_keyBusinessName, state.businessName);
    await _prefs?.setString(_keyBusinessType, state.businessType);
    await _prefs?.setString(_keyRegNumber, state.registrationNumber);
    await _prefs?.setString(_keyBusinessEmail, state.businessEmail);
    await _prefs?.setString(_keyAddressLine, state.addressLine);
    await _prefs?.setString(_keyCity, state.city);
    await _prefs?.setString(_keyStateName, state.stateName);
    await _prefs?.setString(_keyCountry, state.country);
    await _prefs?.setString(_keyBvn, state.bvn);
    await _prefs?.setBool(_keyIsBvnVerified, state.isBvnVerified);
    await _prefs?.setString(_keyNin, state.nin);
    await _prefs?.setBool(_keyIsNinVerified, state.isNinVerified);
    await _prefs?.setBool(_keyIsLivenessVerified, state.isLivenessVerified);
    if (state.livenessImagePath != null) {
      await _prefs?.setString(_keyLivenessImagePath, state.livenessImagePath!);
    }
    await _prefs?.setString(_keySelectedDocType, state.selectedDocType);
    if (state.docPath != null) {
      await _prefs?.setString(_keyDocPath, state.docPath!);
    }
    if (state.docFileName != null) {
      await _prefs?.setString(_keyDocFileName, state.docFileName!);
    }
    if (state.docFileSize != null) {
      await _prefs?.setString(_keyDocFileSize, state.docFileSize!);
    }
    await _prefs?.setBool(_keyIsDocUploaded, state.isDocUploaded);
    await _prefs?.setInt(_keyStatus, state.status.index);
    await _prefs?.setInt(_keyTierLevel, state.tierLevel.index);
  }

  @override
  Future<bool> verifyBvn(String bvn) async {
    await Future.delayed(const Duration(milliseconds: 1000));
    final cleanBvn = bvn.trim();
    // Failed condition for testing error flow: "00000000000"
    if (cleanBvn == '00000000000') {
      return false;
    }
    // Must be 11 numeric digits
    return cleanBvn.length == 11 && RegExp(r'^\d+$').hasMatch(cleanBvn);
  }

  @override
  Future<bool> verifyNin(String nin) async {
    await Future.delayed(const Duration(milliseconds: 1000));
    final cleanNin = nin.trim();
    // Failed condition for testing error flow: "00000000000"
    if (cleanNin == '00000000000') {
      return false;
    }
    // Must be 11 numeric digits
    return cleanNin.length == 11 && RegExp(r'^\d+$').hasMatch(cleanNin);
  }

  @override
  Future<bool> verifyLiveness(String imagePath) async {
    await Future.delayed(const Duration(milliseconds: 1200));
    return imagePath.isNotEmpty;
  }

  @override
  Future<bool> uploadDocument(String docType, String docPath) async {
    await Future.delayed(const Duration(milliseconds: 1000));
    return docPath.isNotEmpty;
  }

  @override
  Future<KycTierLevel> submitKyc(KycState state) async {
    await Future.delayed(const Duration(milliseconds: 1500));

    KycTierLevel newTier = KycTierLevel.tier2;
    if (state.isLivenessVerified && state.isDocUploaded && state.isAddressValid) {
      newTier = KycTierLevel.tier3;
    }

    final updatedState = state.copyWith(
      status: KycStatus.verified,
      tierLevel: newTier,
      isLoading: false,
    );

    await saveKycState(updatedState);
    return newTier;
  }

  @override
  Future<void> resetKyc() async {
    if (_prefs == null) return;
    await _prefs?.remove(_keyAccountType);
    await _prefs?.remove(_keyFirstName);
    await _prefs?.remove(_keyLastName);
    await _prefs?.remove(_keyDob);
    await _prefs?.remove(_keyGender);
    await _prefs?.remove(_keyNationality);
    await _prefs?.remove(_keyBusinessName);
    await _prefs?.remove(_keyBusinessType);
    await _prefs?.remove(_keyRegNumber);
    await _prefs?.remove(_keyBusinessEmail);
    await _prefs?.remove(_keyAddressLine);
    await _prefs?.remove(_keyCity);
    await _prefs?.remove(_keyStateName);
    await _prefs?.remove(_keyCountry);
    await _prefs?.remove(_keyBvn);
    await _prefs?.remove(_keyIsBvnVerified);
    await _prefs?.remove(_keyNin);
    await _prefs?.remove(_keyIsNinVerified);
    await _prefs?.remove(_keyIsLivenessVerified);
    await _prefs?.remove(_keyLivenessImagePath);
    await _prefs?.remove(_keySelectedDocType);
    await _prefs?.remove(_keyDocPath);
    await _prefs?.remove(_keyDocFileName);
    await _prefs?.remove(_keyDocFileSize);
    await _prefs?.remove(_keyIsDocUploaded);
    await _prefs?.remove(_keyStatus);
    await _prefs?.remove(_keyTierLevel);
  }
}
