import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/env.dart';
import '../../../core/network/api_client.dart';

class Beneficiary {
  final String id;
  final String name;
  final String accountOrPhone;
  final String bankName;
  final String? bankCode;
  final String? category;
  final String? serviceId;
  final DateTime? lastUsedAt;

  const Beneficiary({
    required this.id,
    required this.name,
    required this.accountOrPhone,
    required this.bankName,
    this.bankCode,
    this.category,
    this.serviceId,
    this.lastUsedAt,
  });

  // Backwards-compatible getter
  String get tagOrAccount => accountOrPhone;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'accountOrPhone': accountOrPhone,
        'bankName': bankName,
        'bankCode': bankCode,
        'category': category,
        'serviceId': serviceId,
        'lastUsedAt': lastUsedAt?.toIso8601String(),
      };

  factory Beneficiary.fromJson(Map<String, dynamic> json) => Beneficiary(
        id: json['id'] as String? ?? 'b_${DateTime.now().millisecondsSinceEpoch}',
        name: json['name'] as String? ?? '',
        accountOrPhone: json['accountOrPhone'] as String? ?? json['accountNumber'] as String? ?? '',
        bankName: json['bankName'] as String? ?? 'PayFlow Account',
        bankCode: json['bankCode'] as String?,
        category: json['category'] as String?,
        serviceId: json['serviceId'] as String?,
        lastUsedAt: json['lastUsedAt'] != null ? DateTime.tryParse(json['lastUsedAt']) : null,
      );
}

class BankItem {
  final String name;
  final String code;
  final String? slug;
  final dynamic id;

  const BankItem({
    required this.name,
    required this.code,
    this.slug,
    this.id,
  });

  factory BankItem.fromJson(Map<String, dynamic> json) => BankItem(
        name: json['name'] as String? ?? '',
        code: json['code'] as String? ?? '',
        slug: json['slug'] as String?,
        id: json['id'],
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'code': code,
        'slug': slug,
        'id': id,
      };
}

class TransferState {
  final List<Beneficiary> recentBeneficiaries;
  final String selectedTransferType; // 'PayFlow User', 'Bank Account'
  final String selectedBank;
  final String selectedBankCode;
  final List<BankItem> availableBanks;
  final bool isProcessing;
  final bool isResolvingAccount;
  final String? resolvedAccountName;
  final String? verifiedRecipient;
  final double? amount;
  final String? errorMessage;

  const TransferState({
    required this.recentBeneficiaries,
    required this.selectedTransferType,
    this.selectedBank = 'GTBank',
    this.selectedBankCode = '058',
    this.availableBanks = const [
      BankItem(name: 'GTBank', code: '058'),
      BankItem(name: 'Kuda Bank', code: '50211'),
      BankItem(name: 'Zenith Bank', code: '057'),
      BankItem(name: 'Access Bank', code: '044'),
      BankItem(name: 'First Bank of Nigeria', code: '011'),
      BankItem(name: 'Wema Bank', code: '035'),
      BankItem(name: 'United Bank For Africa', code: '033'),
    ],
    required this.isProcessing,
    this.isResolvingAccount = false,
    this.resolvedAccountName,
    this.verifiedRecipient,
    this.amount,
    this.errorMessage,
  });

  TransferState copyWith({
    List<Beneficiary>? recentBeneficiaries,
    String? selectedTransferType,
    String? selectedBank,
    String? selectedBankCode,
    List<BankItem>? availableBanks,
    bool? isProcessing,
    bool? isResolvingAccount,
    String? resolvedAccountName,
    String? verifiedRecipient,
    double? amount,
    String? errorMessage,
    bool clearRecipient = false,
    bool clearAmount = false,
  }) {
    return TransferState(
      recentBeneficiaries: recentBeneficiaries ?? this.recentBeneficiaries,
      selectedTransferType: selectedTransferType ?? this.selectedTransferType,
      selectedBank: selectedBank ?? this.selectedBank,
      selectedBankCode: selectedBankCode ?? this.selectedBankCode,
      availableBanks: availableBanks ?? this.availableBanks,
      isProcessing: isProcessing ?? this.isProcessing,
      isResolvingAccount: isResolvingAccount ?? this.isResolvingAccount,
      resolvedAccountName: clearRecipient
          ? null
          : (resolvedAccountName ?? this.resolvedAccountName),
      verifiedRecipient: clearRecipient
          ? null
          : (verifiedRecipient ?? this.verifiedRecipient),
      amount: clearAmount ? null : (amount ?? this.amount),
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class TransferViewModel extends StateNotifier<TransferState> {
  static const String _beneficiariesStorageKey = 'payflow_saved_beneficiaries';

  static const List<Beneficiary> _sampleBeneficiaries = [
    Beneficiary(
      id: 'b1',
      name: 'Sarah Connor',
      accountOrPhone: '08012345678',
      bankName: 'PayFlow Account',
    ),
    Beneficiary(
      id: 'b2',
      name: 'Michael Scott',
      accountOrPhone: '0123456789',
      bankName: 'GTBank',
      bankCode: '058',
    ),
    Beneficiary(
      id: 'b3',
      name: 'Pam Beesly',
      accountOrPhone: '9876543210',
      bankName: 'Kuda Bank',
      bankCode: '50211',
    ),
  ];

  static bool isMockBeneficiary(Beneficiary b) =>
      b.id == 'b1' || b.id == 'b2' || b.id == 'b3';

  TransferViewModel()
      : super(
          TransferState(
            selectedTransferType: 'PayFlow User',
            selectedBank: 'GTBank',
            selectedBankCode: '058',
            isProcessing: false,
            recentBeneficiaries: Env.isMockMode ? _sampleBeneficiaries : const [],
          ),
        ) {
    loadBeneficiaries();
    fetchBanks();
  }

  Future<void> loadBeneficiaries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_beneficiariesStorageKey);
      if (rawJson != null && rawJson.isNotEmpty) {
        final List<dynamic> list = jsonDecode(rawJson);
        final loaded = list.map((item) => Beneficiary.fromJson(item)).toList();
        final validLoaded = Env.isMockMode
            ? loaded
            : loaded.where((b) => !isMockBeneficiary(b)).toList();
        if (validLoaded.isNotEmpty || !Env.isMockMode) {
          state = state.copyWith(recentBeneficiaries: validLoaded);
        }
      }

      if (!Env.isMockMode && defaultApiClient.baseUrl.isNotEmpty) {
        try {
          final res = await defaultApiClient.get('/v1/users/beneficiaries');
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            if (data['beneficiaries'] != null && data['beneficiaries'] is List) {
              final remoteList = (data['beneficiaries'] as List)
                  .map((item) => Beneficiary.fromJson(item))
                  .where((b) => !isMockBeneficiary(b))
                  .toList();
              if (remoteList.isNotEmpty) {
                final current = state.recentBeneficiaries;
                final combined = [
                  ...current,
                  ...remoteList.where((r) => !current.any((c) => c.accountOrPhone == r.accountOrPhone)),
                ];
                state = state.copyWith(recentBeneficiaries: combined);
              }
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> saveBeneficiary(Beneficiary ben) async {
    try {
      final currentList = Env.isMockMode
          ? state.recentBeneficiaries
          : state.recentBeneficiaries.where((b) => !isMockBeneficiary(b)).toList();

      final updated = [
        ben,
        ...currentList.where((b) => b.accountOrPhone != ben.accountOrPhone),
      ];
      state = state.copyWith(recentBeneficiaries: updated);

      final prefs = await SharedPreferences.getInstance();
      final rawJson = jsonEncode(updated.map((b) => b.toJson()).toList());
      await prefs.setString(_beneficiariesStorageKey, rawJson);

      if (!Env.isMockMode && defaultApiClient.baseUrl.isNotEmpty) {
        try {
          // ignore: unawaited_futures
          defaultApiClient.post('/v1/users/beneficiaries', body: {
            'name': ben.name,
            'accountNumber': ben.accountOrPhone,
            'bankCode': ben.bankCode,
            'bankName': ben.bankName,
            'category': ben.category ?? 'bank',
            'serviceId': ben.serviceId,
            'phone': ben.accountOrPhone,
          });
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> fetchBanks() async {
    if (Env.isMockMode || defaultApiClient.baseUrl.isEmpty) return;

    try {
      final response = await defaultApiClient.get('/v1/transfers/banks');
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List<dynamic> data = json['data'] ?? [];
        final fetchedBanks = data.map((b) => BankItem.fromJson(b)).toList();
        if (fetchedBanks.isNotEmpty) {
          state = state.copyWith(availableBanks: fetchedBanks);
        }
      }
    } catch (_) {}
  }

  void resetRecipient() {
    state = state.copyWith(
      clearRecipient: true,
      errorMessage: null,
      isResolvingAccount: false,
    );
  }

  void resetTransferState() {
    final defaultBank = state.availableBanks.isNotEmpty
        ? state.availableBanks.first
        : const BankItem(name: 'GTBank', code: '058');

    state = TransferState(
      recentBeneficiaries: state.recentBeneficiaries,
      selectedTransferType: 'PayFlow User',
      selectedBank: defaultBank.name,
      selectedBankCode: defaultBank.code,
      availableBanks: state.availableBanks,
      isProcessing: false,
      isResolvingAccount: false,
      resolvedAccountName: null,
      verifiedRecipient: null,
      amount: null,
      errorMessage: null,
    );
  }

  void setAmount(double? amt) {
    state = state.copyWith(amount: amt);
  }

  Future<String?> resolvePayFlowUser(String phone) async {
    state = state.copyWith(
      isResolvingAccount: true,
      clearRecipient: true,
      errorMessage: null,
    );

    if (Env.isMockMode || defaultApiClient.baseUrl.isEmpty) {
      if (phone == '08012345678' || phone.endsWith('12345678')) {
        const name = 'Sarah Connor';
        state = state.copyWith(
          isResolvingAccount: false,
          resolvedAccountName: name,
          verifiedRecipient: name,
          errorMessage: null,
        );
        return name;
      }
      const errorMsg = 'No PayFlow user found with this number';
      state = state.copyWith(
        isResolvingAccount: false,
        clearRecipient: true,
        errorMessage: errorMsg,
      );
      return null;
    }

    try {
      final response = await defaultApiClient.get('/v1/users/$phone/profile');
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final name = json['displayName'] as String? ?? 'PayFlow User ($phone)';
        state = state.copyWith(
          isResolvingAccount: false,
          resolvedAccountName: name,
          verifiedRecipient: name,
          errorMessage: null,
        );
        return name;
      } else if (response.statusCode == 404) {
        const errorMsg = 'No PayFlow user found with this number';
        state = state.copyWith(
          isResolvingAccount: false,
          clearRecipient: true,
          errorMessage: errorMsg,
        );
        return null;
      } else {
        final errorMsg = 'Unable to resolve user (HTTP ${response.statusCode})';
        state = state.copyWith(
          isResolvingAccount: false,
          clearRecipient: true,
          errorMessage: errorMsg,
        );
        return null;
      }
    } catch (_) {
      state = state.copyWith(
        isResolvingAccount: false,
        clearRecipient: true,
        errorMessage: 'Network error resolving PayFlow user',
      );
      return null;
    }
  }

  Future<String?> resolveBankAccount(String accountNumber, String bankCode) async {
    state = state.copyWith(
      isResolvingAccount: true,
      clearRecipient: true,
      errorMessage: null,
    );

    if (Env.isMockMode || defaultApiClient.baseUrl.isEmpty) {
      if (accountNumber == '0123456789') {
        const mockName = 'ALEX CHUKWU';
        state = state.copyWith(
          isResolvingAccount: false,
          resolvedAccountName: mockName,
          verifiedRecipient: mockName,
          errorMessage: null,
        );
        return mockName;
      }
      const errorMsg = 'Could not resolve account name for this bank';
      state = state.copyWith(
        isResolvingAccount: false,
        clearRecipient: true,
        errorMessage: errorMsg,
      );
      return null;
    }

    try {
      final response = await defaultApiClient.get(
        '/v1/transfers/resolve-account?accountNumber=$accountNumber&bankCode=$bankCode',
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final accountName = (json['account_name'] ?? json['data']?['account_name']) as String?;
        if (accountName != null && accountName.isNotEmpty) {
          state = state.copyWith(
            isResolvingAccount: false,
            resolvedAccountName: accountName,
            verifiedRecipient: accountName,
            errorMessage: null,
          );
          return accountName;
        }
      }

      String errorMsg = 'Could not resolve account name for this bank';
      try {
        final json = jsonDecode(response.body);
        errorMsg = json['message'] ?? json['error'] ?? errorMsg;
      } catch (_) {}

      state = state.copyWith(
        isResolvingAccount: false,
        clearRecipient: true,
        errorMessage: errorMsg,
      );
      return null;
    } catch (_) {
      state = state.copyWith(
        isResolvingAccount: false,
        clearRecipient: true,
        errorMessage: 'Network error resolving bank account',
      );
      return null;
    }
  }

  void setTransferType(String type) {
    state = state.copyWith(
      selectedTransferType: type,
      clearRecipient: true,
      errorMessage: null,
    );
  }

  void setSelectedBank(String bankName, String bankCode) {
    state = state.copyWith(
      selectedBank: bankName,
      selectedBankCode: bankCode,
      clearRecipient: true,
      errorMessage: null,
    );
  }

  void setErrorMessage(String? msg) {
    state = state.copyWith(errorMessage: msg);
  }

  void setIsProcessing(bool processing) {
    state = state.copyWith(isProcessing: processing);
  }
}

final transferViewModelProvider =
    StateNotifierProvider<TransferViewModel, TransferState>((ref) {
  return TransferViewModel();
});
