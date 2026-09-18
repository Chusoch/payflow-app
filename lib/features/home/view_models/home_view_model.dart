import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/view_models/auth_view_model.dart';
import '../../profile/view_models/profile_view_model.dart';
import '../../wallet/view_models/wallet_view_model.dart';
import '../models/promo_banner.dart';
import '../models/transaction_item.dart';
import '../repositories/home_repository.dart';
import '../repositories/mock_home_repository.dart';

export '../models/promo_banner.dart';
export '../models/transaction_item.dart';
export '../repositories/home_repository.dart';

class HomeState {
  final String userName;
  final String accountNumber;
  final double balance;
  final double monthlyIncome;
  final double monthlyExpenses;
  final bool isBalanceVisible;
  final List<TransactionItem> recentTransactions;
  final List<PromoBanner> promoBanners;
  final int currentBannerIndex;
  final bool isLoading;

  const HomeState({
    required this.userName,
    required this.accountNumber,
    required this.balance,
    required this.monthlyIncome,
    required this.monthlyExpenses,
    required this.isBalanceVisible,
    required this.recentTransactions,
    required this.promoBanners,
    this.currentBannerIndex = 0,
    this.isLoading = false,
  });

  HomeState copyWith({
    String? userName,
    String? accountNumber,
    double? balance,
    double? monthlyIncome,
    double? monthlyExpenses,
    bool? isBalanceVisible,
    List<TransactionItem>? recentTransactions,
    List<PromoBanner>? promoBanners,
    int? currentBannerIndex,
    bool? isLoading,
  }) {
    return HomeState(
      userName: userName ?? this.userName,
      accountNumber: accountNumber ?? this.accountNumber,
      balance: balance ?? this.balance,
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      monthlyExpenses: monthlyExpenses ?? this.monthlyExpenses,
      isBalanceVisible: isBalanceVisible ?? this.isBalanceVisible,
      recentTransactions: recentTransactions ?? this.recentTransactions,
      promoBanners: promoBanners ?? this.promoBanners,
      currentBannerIndex: currentBannerIndex ?? this.currentBannerIndex,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class HomeViewModel extends StateNotifier<HomeState> {
  final HomeRepository _repository;
  final ProfileRepository? _profileRepository;
  final Ref? _ref;

  HomeViewModel({
    HomeRepository? repository,
    ProfileRepository? profileRepository,
    Ref? ref,
    String? initialUserName,
    String? initialAccountNumber,
  })  : _repository = repository ?? MockHomeRepository(),
        _profileRepository = profileRepository,
        _ref = ref,
        super(
          HomeState(
            userName: initialUserName ?? '',
            accountNumber: initialAccountNumber ?? '',
            balance: 245850.75,
            monthlyIncome: 350000.00,
            monthlyExpenses: 104149.25,
            isBalanceVisible: true,
            recentTransactions: [],
            promoBanners: [],
            currentBannerIndex: 0,
            isLoading: true,
          ),
        ) {
    _init();
  }

  Future<void> _init() async {
    await _loadHomeData();
    await loadUserProfile();

    if (_ref != null) {
      _ref.listen<ProfileState>(profileViewModelProvider, (previous, next) {
        if (next.displayName != previous?.displayName ||
            next.accountNumber != previous?.accountNumber) {
          state = state.copyWith(
            userName: next.displayName,
            accountNumber: next.accountNumber,
          );
        }
      });
    }
  }

  Future<void> _loadHomeData() async {
    final banners = await _repository.getPromoBanners();
    final transactions = await _repository.getRecentTransactions();

    state = state.copyWith(
      promoBanners: banners,
      recentTransactions: transactions,
      isLoading: false,
    );
  }

  /// Refreshes home data, user profile, and synchronizes with WalletViewModel.refreshWallet().
  Future<void> refresh() async {
    final futures = <Future<void>>[
      _loadHomeData(),
      loadUserProfile(),
    ];
    if (_ref != null) {
      futures.add(_ref.read(walletViewModelProvider.notifier).refreshWallet());
    }
    await Future.wait(futures);
  }

  Future<void> loadUserProfile() async {
    String? phone;
    if (_ref != null) {
      final authState = _ref.read(authViewModelProvider);
      phone = authState.phoneNumber ??
          _ref.read(authRepositoryProvider).getAuthenticatedPhone();
    }

    if (phone == null || phone.isEmpty) {
      if (state.userName.isEmpty) {
        state = state.copyWith(userName: 'User');
      }
      return;
    }

    final formattedPhone = phone.startsWith('+')
        ? phone
        : '+234${phone.replaceFirst(RegExp(r'^0'), '')}';

    final cleanDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final accountNum = cleanDigits.length >= 10
        ? cleanDigits.substring(cleanDigits.length - 10)
        : cleanDigits;

    try {
      final ref = _ref;
      final ProfileRepository repo = _profileRepository ??
          (ref != null
              ? ref.read(profileRepositoryProvider)
              : NetworkProfileRepository());
      final profile = await repo.fetchProfile(formattedPhone);

      final displayName = (profile.fullName != null && profile.fullName!.trim().isNotEmpty)
          ? profile.fullName!.trim()
          : (profile.displayName.isNotEmpty &&
                  !profile.displayName.startsWith('User +') &&
                  !profile.displayName.startsWith('User 0')
              ? profile.displayName
              : 'User');

      state = state.copyWith(
        userName: displayName,
        accountNumber: accountNum,
      );
    } catch (_) {
      final savedName = _ref?.read(authRepositoryProvider).getSavedFullName();
      state = state.copyWith(
        userName: savedName?.isNotEmpty == true ? savedName! : 'User',
        accountNumber: accountNum,
      );
    }
  }

  void updateFromProfile(UserProfile profile) {
    final cleanDigits = profile.phone.replaceAll(RegExp(r'[^0-9]'), '');
    final accountNum = cleanDigits.length >= 10
        ? cleanDigits.substring(cleanDigits.length - 10)
        : cleanDigits;
    final name = (profile.fullName != null && profile.fullName!.trim().isNotEmpty)
        ? profile.fullName!.trim()
        : (profile.displayName.isNotEmpty &&
                !profile.displayName.startsWith('User +') &&
                !profile.displayName.startsWith('User 0')
            ? profile.displayName
            : 'User');
    state = state.copyWith(
      userName: name,
      accountNumber: accountNum,
    );
  }

  void toggleBalanceVisibility() {
    state = state.copyWith(isBalanceVisible: !state.isBalanceVisible);
  }

  void setBannerIndex(int index) {
    state = state.copyWith(currentBannerIndex: index);
  }
}

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return MockHomeRepository();
});

final homeViewModelProvider =
    StateNotifierProvider<HomeViewModel, HomeState>((ref) {
  final repository = ref.watch(homeRepositoryProvider);
  final profileRepository = ref.watch(profileRepositoryProvider);
  return HomeViewModel(
    repository: repository,
    profileRepository: profileRepository,
    ref: ref,
  );
});
