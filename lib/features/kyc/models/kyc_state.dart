import 'kyc_tier.dart';

class KycState {
  final AccountType accountType;
  // Personal Info (Individual)
  final String firstName;
  final String lastName;
  final String dob;
  final String gender;
  final String nationality;

  // Business Info (Business)
  final String businessName;
  final String businessType;
  final String registrationNumber;
  final String businessEmail;

  // Address Details
  final String addressLine;
  final String city;
  final String stateName;
  final String country;

  // Identity Verification (BVN & NIN)
  final String bvn;
  final bool isBvnVerified;
  final String? bvnError;

  final String nin;
  final bool isNinVerified;
  final String? ninError;

  // Liveness Verification
  final bool isLivenessVerified;
  final String? livenessImagePath;
  final String? livenessError;

  // Document Upload
  final String selectedDocType;
  final String? docPath;
  final String? docFileName;
  final String? docFileSize;
  final bool isDocUploaded;
  final String? docError;

  // State Management & Step Flow
  final int currentStepIndex;
  final KycStatus status;
  final KycTierLevel tierLevel;
  final bool isLoading;
  final String? errorMessage;

  const KycState({
    this.accountType = AccountType.individual,
    this.firstName = '',
    this.lastName = '',
    this.dob = '',
    this.gender = 'Male',
    this.nationality = 'Nigeria',
    this.businessName = '',
    this.businessType = 'Sole Proprietorship',
    this.registrationNumber = '',
    this.businessEmail = '',
    this.addressLine = '',
    this.city = '',
    this.stateName = 'Lagos',
    this.country = 'Nigeria',
    this.bvn = '',
    this.isBvnVerified = false,
    this.bvnError,
    this.nin = '',
    this.isNinVerified = false,
    this.ninError,
    this.isLivenessVerified = false,
    this.livenessImagePath,
    this.livenessError,
    this.selectedDocType = "National Identity Card (NIN Slip)",
    this.docPath,
    this.docFileName,
    this.docFileSize,
    this.isDocUploaded = false,
    this.docError,
    this.currentStepIndex = 0,
    this.status = KycStatus.notStarted,
    this.tierLevel = KycTierLevel.tier1,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get isPersonalInfoValid {
    if (accountType == AccountType.individual) {
      return firstName.trim().isNotEmpty &&
          lastName.trim().isNotEmpty &&
          dob.trim().isNotEmpty &&
          nationality.trim().isNotEmpty;
    } else {
      return businessName.trim().isNotEmpty &&
          businessType.trim().isNotEmpty &&
          businessEmail.trim().contains('@');
    }
  }

  bool get isAddressValid {
    return addressLine.trim().isNotEmpty &&
        city.trim().isNotEmpty &&
        stateName.trim().isNotEmpty &&
        country.trim().isNotEmpty;
  }

  bool get isIdentityVerified => isBvnVerified && isNinVerified;

  bool get isReadyForSubmission {
    return isPersonalInfoValid &&
        isAddressValid &&
        isBvnVerified &&
        isNinVerified &&
        isLivenessVerified &&
        isDocUploaded;
  }

  KycState copyWith({
    AccountType? accountType,
    String? firstName,
    String? lastName,
    String? dob,
    String? gender,
    String? nationality,
    String? businessName,
    String? businessType,
    String? registrationNumber,
    String? businessEmail,
    String? addressLine,
    String? city,
    String? stateName,
    String? country,
    String? bvn,
    bool? isBvnVerified,
    String? bvnError,
    String? nin,
    bool? isNinVerified,
    String? ninError,
    bool? isLivenessVerified,
    String? livenessImagePath,
    String? livenessError,
    String? selectedDocType,
    String? docPath,
    String? docFileName,
    String? docFileSize,
    bool? isDocUploaded,
    String? docError,
    int? currentStepIndex,
    KycStatus? status,
    KycTierLevel? tierLevel,
    bool? isLoading,
    String? errorMessage,
  }) {
    return KycState(
      accountType: accountType ?? this.accountType,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      nationality: nationality ?? this.nationality,
      businessName: businessName ?? this.businessName,
      businessType: businessType ?? this.businessType,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      businessEmail: businessEmail ?? this.businessEmail,
      addressLine: addressLine ?? this.addressLine,
      city: city ?? this.city,
      stateName: stateName ?? this.stateName,
      country: country ?? this.country,
      bvn: bvn ?? this.bvn,
      isBvnVerified: isBvnVerified ?? this.isBvnVerified,
      bvnError: bvnError,
      nin: nin ?? this.nin,
      isNinVerified: isNinVerified ?? this.isNinVerified,
      ninError: ninError,
      isLivenessVerified: isLivenessVerified ?? this.isLivenessVerified,
      livenessImagePath: livenessImagePath ?? this.livenessImagePath,
      livenessError: livenessError,
      selectedDocType: selectedDocType ?? this.selectedDocType,
      docPath: docPath ?? this.docPath,
      docFileName: docFileName ?? this.docFileName,
      docFileSize: docFileSize ?? this.docFileSize,
      isDocUploaded: isDocUploaded ?? this.isDocUploaded,
      docError: docError,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      status: status ?? this.status,
      tierLevel: tierLevel ?? this.tierLevel,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}
