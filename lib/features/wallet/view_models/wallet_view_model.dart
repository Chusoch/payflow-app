import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/env.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/payment/models/payment_status.dart';
import '../../../core/payment/providers/mock_payment_provider.dart';
import '../../../core/payment/providers/payment_provider.dart';
import '../../../core/payment/services/payment_service.dart';
import '../repositories/wallet_repository.dart';
import '../../notifications/models/notification_item.dart';
import '../../home/models/transaction_item.dart';
import '../../auth/models/auth_state.dart';
import '../../auth/view_models/auth_view_model.dart';

class WalletState {
  final double mainBalance;
  final List<TransactionItem> transactions;
  final String activeFilter; // 'All', 'Money In', 'Money Out'

  const WalletState({
    required this.mainBalance,
    required this.transactions,
    this.activeFilter = 'All',
  });

  WalletState copyWith({
    double? mainBalance,
    List<TransactionItem>? transactions,
    String? activeFilter,
  }) {
    return WalletState(
      mainBalance: mainBalance ?? this.mainBalance,
      transactions: transactions ?? this.transactions,
      activeFilter: activeFilter ?? this.activeFilter,
    );
  }

  double get balance => mainBalance;
  List<TransactionItem> get recentTransactions => transactions.take(5).toList();

  List<TransactionItem> get filteredTransactions {
    if (activeFilter == 'Money In') {
      return transactions.where((tx) => tx.isCredit).toList();
    } else if (activeFilter == 'Money Out') {
      return transactions.where((tx) => !tx.isCredit).toList();
    }
    return transactions;
  }
}

class WalletViewModel extends StateNotifier<WalletState> {
  static List<TransactionItem> get _sampleTransactions => [
    TransactionItem(
      id: 'tx_1',
      title: 'Electricity Token Purchase',
      category: 'Electricity',
      amount: 12500.00,
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      isCredit: false,
      status: 'Completed',
      reference: 'PF-ELE-948201',
      recipientOrSender: 'Ikeja Electric (Meter: 4501928374)',
      transferType: 'Electricity Bill',
      token: '4920-1849-2048-1039',
      narration: 'Prepaid Token Recharge',
    ),
    TransactionItem(
      id: 'tx_2',
      title: 'Salary Deposit - TechCorp',
      category: 'Income',
      amount: 350000.00,
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      isCredit: true,
      status: 'Completed',
      reference: 'PF-TXN-748392',
      recipientOrSender: 'TechCorp Ltd',
      transferType: 'Direct Deposit',
      narration: 'Monthly Salary Payment',
    ),
    TransactionItem(
      id: 'tx_3',
      title: 'Airtime Recharge (MTN)',
      category: 'Airtime',
      amount: 2000.00,
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      isCredit: false,
      status: 'Completed',
      reference: 'PF-AIR-639201',
      recipientOrSender: '08012345678',
      transferType: 'Airtime Purchase',
      narration: 'MTN Airtime ₦2,000',
    ),
    TransactionItem(
      id: 'tx_4',
      title: 'Transfer to Sarah Connor',
      category: 'Transfer',
      amount: 15000.00,
      timestamp: DateTime.now().subtract(const Duration(days: 3)),
      isCredit: false,
      status: 'Completed',
      reference: 'PF-TRF-528401',
      recipientOrSender: 'Sarah Connor (GTBank)',
      transferType: 'Bank Transfer',
      narration: 'Lunch & Groceries',
    ),
    TransactionItem(
      id: 'tx_5',
      title: 'Data Bundle (Airtel)',
      category: 'Data',
      amount: 3500.00,
      timestamp: DateTime.now().subtract(const Duration(days: 4)),
      isCredit: false,
      status: 'Completed',
      reference: 'PF-DAT-419203',
      recipientOrSender: '08123456789',
      transferType: 'Data Purchase',
      narration: 'Airtel 10GB Data',
    ),
  ];

  StreamSubscription<NotificationItem>? _notificationSubscription;

  final PaymentService _paymentService;
  final WalletRepository _walletRepository;

  WalletViewModel({
    PaymentService? paymentService,
    WalletRepository? walletRepository,
  })  : _paymentService = paymentService ?? PaymentService(),
        _walletRepository = walletRepository ?? ApiWalletRepository(),
        super(
          WalletState(
            mainBalance: Env.isMockMode ? 245850.75 : 0.0,
            transactions: Env.isMockMode ? _sampleTransactions : const [],
          ),
        ) {
    if (!Env.isMockMode) {
      refreshWallet();
    }
    _notificationSubscription = NotificationService().onNotificationReceived.listen((item) {
      if (item.category == NotificationCategory.transactions) {
        refreshWallet();
      }
    });
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  PaymentService get paymentService => _paymentService;

  /// Fetches authoritative wallet balance for signed-in user via WalletRepository.
  Future<void> fetchMeBalance() async {
    if (Env.isMockMode) return;

    final balance = await _walletRepository.getBalance();
    if (balance != null) {
      state = state.copyWith(mainBalance: balance);
    }
  }

  /// Fetches authoritative transaction history for signed-in user via WalletRepository.
  Future<void> fetchTransactions() async {
    if (Env.isMockMode) return;

    final items = await _walletRepository.getTransactions();
    if (items.isNotEmpty) {
      state = state.copyWith(transactions: items);
    }
  }

  /// Alias for [fetchTransactions] as requested.
  Future<void> getTransactions() => fetchTransactions();

  /// Returns recent transactions from wallet state.
  List<TransactionItem> get recentTransactions => state.recentTransactions;

  /// Refreshes both wallet balance and authoritative transaction history in parallel.
  Future<void> refreshWallet() async {
    await Future.wait([
      fetchMeBalance(),
      fetchTransactions(),
    ]);
  }

  /// Alias for [refreshWallet] invoked upon session restoration and authentication events.
  Future<void> fetchWalletData() => refreshWallet();

  /// Adds a transaction to the local state immediately for real-time feed updates.
  void addTransaction(TransactionItem item) {
    final exists = state.transactions.any((tx) =>
        (tx.id.isNotEmpty && tx.id == item.id) ||
        (tx.reference != null && item.reference != null && tx.reference == item.reference));
    if (!exists) {
      state = state.copyWith(
        transactions: [item, ...state.transactions],
      );
    }
  }

  /// Fund wallet using verified payment lifecycle.
  /// Balance MUTATION occurs ONLY after `verification.isConfirmed == true`.
  Future<PaymentVerification> processVerifiedFunding({
    required double amount,
    required String method,
    PaymentProvider? customProvider,
  }) async {
    final refCode = 'PF-TOP-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final request = PaymentRequest(
      transactionRef: refCode,
      amount: amount,
      customerIdentifier: method,
      paymentType: 'wallet_funding',
      description: 'Fund Wallet ($method)',
    );

    PaymentService serviceToUse = _paymentService;
    if (customProvider != null) {
      serviceToUse = PaymentService(
        customProviders: {customProvider.providerType: customProvider},
      );
      serviceToUse.selectProvider(customProvider.providerType);
    } else {
      serviceToUse.selectProvider(PaymentProviderType.paystack);
    }

    final verification = await serviceToUse.processPayment(request);

    if (verification.isConfirmed) {
      final newTx = TransactionItem(
        id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Fund Wallet ($method)',
        category: 'Top Up',
        amount: amount,
        timestamp: DateTime.now(),
        isCredit: true,
        status: 'Completed',
        reference: refCode,
        recipientOrSender: method,
        transferType: 'Wallet Funding',
      );

      state = state.copyWith(
        mainBalance: state.mainBalance + amount,
        transactions: [newTx, ...state.transactions],
      );

      NotificationService().showNotification(
        title: 'Wallet Funded Successfully',
        body: 'Your account was credited with ₦${amount.toStringAsFixed(2)} via $method.',
        category: NotificationCategory.transactions,
        payload: {'transactionRef': refCode},
      );
    }

    return verification;
  }

  /// Send money transfer using verified payment lifecycle.
  Future<PaymentVerification> processVerifiedTransfer({
    required String recipient,
    required String transferType,
    required double amount,
    String? note,
    String? bankName,
    PaymentProvider? customProvider,
  }) async {
    if (amount <= 0 || amount > state.mainBalance) {
      return PaymentVerification(
        transactionRef: 'PF-TRF-FAILED',
        amountPaid: 0.0,
        status: PaymentStatus.failed,
        isConfirmed: false,
        verifiedAt: DateTime.now(),
        failureReason: 'Insufficient balance or invalid transfer amount',
      );
    }

    final refCode = 'PF-TRF-${DateTime.now().millisecondsSinceEpoch.toString().substring(4)}';
    final request = PaymentRequest(
      transactionRef: refCode,
      amount: amount,
      customerIdentifier: recipient,
      paymentType: 'transfer',
      description: 'Transfer to $recipient',
    );

    PaymentService serviceToUse = _paymentService;
    if (customProvider != null) {
      serviceToUse = PaymentService(
        customProviders: {customProvider.providerType: customProvider},
      );
      serviceToUse.selectProvider(customProvider.providerType);
    }

    final verification = await serviceToUse.processPayment(request);

    if (verification.isConfirmed) {
      final newTx = TransactionItem(
        id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Transfer to $recipient',
        category: 'Transfer',
        amount: amount,
        timestamp: DateTime.now(),
        isCredit: false,
        status: 'Completed',
        reference: refCode,
        recipientOrSender: '$recipient ${bankName != null ? '($bankName)' : ''}'.trim(),
        transferType: transferType,
      );

      state = state.copyWith(
        mainBalance: state.mainBalance - amount,
        transactions: [newTx, ...state.transactions],
      );

      NotificationService().showNotification(
        title: 'Transfer Sent Successfully',
        body: '₦${amount.toStringAsFixed(2)} sent to $recipient ($refCode).',
        category: NotificationCategory.transactions,
        payload: {'transactionRef': refCode},
      );
    }

    return verification;
  }

  /// Process utility payment using verified payment lifecycle.
  Future<PaymentVerification> processVerifiedServicePayment({
    required String title,
    required String category,
    required double amount,
    required String identifier,
    String? referencePrefix,
    String? token,
    String? narration,
    PaymentProvider? customProvider,
  }) async {
    if (amount <= 0 || amount > state.mainBalance) {
      return PaymentVerification(
        transactionRef: 'PF-SVC-FAILED',
        amountPaid: 0.0,
        status: PaymentStatus.failed,
        isConfirmed: false,
        verifiedAt: DateTime.now(),
        failureReason: 'Insufficient balance or invalid service amount',
      );
    }

    final prefix = referencePrefix ?? 'PF-SVC-';
    final refCode = '$prefix${DateTime.now().millisecondsSinceEpoch.toString().substring(4)}';
    final request = PaymentRequest(
      transactionRef: refCode,
      amount: amount,
      customerIdentifier: identifier,
      paymentType: category.toLowerCase(),
      description: title,
    );

    PaymentService serviceToUse = _paymentService;
    if (customProvider != null) {
      serviceToUse = PaymentService(
        customProviders: {customProvider.providerType: customProvider},
      );
      serviceToUse.selectProvider(customProvider.providerType);
    }

    final verification = await serviceToUse.processPayment(request);

    if (verification.isConfirmed) {
      final newTx = TransactionItem(
        id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        category: category,
        amount: amount,
        timestamp: DateTime.now(),
        isCredit: false,
        status: 'Completed',
        reference: refCode,
        recipientOrSender: identifier,
        transferType: 'Utility Payment',
        token: token,
        narration: narration,
      );

      state = state.copyWith(
        mainBalance: state.mainBalance - amount,
        transactions: [newTx, ...state.transactions],
      );

      NotificationService().showNotification(
        title: 'Utility Payment Successful',
        body: '₦${amount.toStringAsFixed(2)} for $title ($refCode) completed.',
        category: NotificationCategory.transactions,
        payload: {'transactionRef': refCode},
      );
    }

    return verification;
  }

  // Synchronous methods for backwards compatibility
  void fundWallet({required double amount, required String method}) {
    final refCode = 'PF-TOP-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final request = PaymentRequest(
      transactionRef: refCode,
      amount: amount,
      customerIdentifier: method,
      paymentType: 'wallet_funding',
      description: 'Fund Wallet ($method)',
    );

    final mockProvider = MockPaymentProvider();
    mockProvider.initializePayment(request);
    mockProvider.verifyPayment(refCode);

    final newTx = TransactionItem(
      id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Fund Wallet ($method)',
      category: 'Top Up',
      amount: amount,
      timestamp: DateTime.now(),
      isCredit: true,
      status: 'Completed',
      reference: refCode,
      recipientOrSender: method,
      transferType: 'Wallet Funding',
    );

    state = state.copyWith(
      mainBalance: state.mainBalance + amount,
      transactions: [newTx, ...state.transactions],
    );
  }

  String sendMoney({
    required String recipient,
    required String transferType,
    required double amount,
    String? note,
    String? bankName,
  }) {
    final refCode = 'PF-TRF-${DateTime.now().millisecondsSinceEpoch.toString().substring(4)}';
    final request = PaymentRequest(
      transactionRef: refCode,
      amount: amount,
      customerIdentifier: recipient,
      paymentType: 'transfer',
      description: 'Transfer to $recipient',
    );

    final mockProvider = MockPaymentProvider();
    mockProvider.initializePayment(request);
    mockProvider.verifyPayment(refCode);

    final newTx = TransactionItem(
      id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Transfer to $recipient',
      category: 'Transfer',
      amount: amount,
      timestamp: DateTime.now(),
      isCredit: false,
      status: 'Completed',
      reference: refCode,
      recipientOrSender: '$recipient ${bankName != null ? '($bankName)' : ''}'.trim(),
      transferType: transferType,
    );

    state = state.copyWith(
      mainBalance: state.mainBalance - amount,
      transactions: [newTx, ...state.transactions],
    );

    return refCode;
  }

  Future<PaymentVerification> payService({
    required String title,
    required String category,
    required double amount,
    required String identifier,
    required PaymentProviderType providerType,
    String? referencePrefix,
    String? token,
    String? narration,
    String? customReference,
    PaymentProvider? customProvider,
  }) async {
    if (amount <= 0 || amount > state.mainBalance) {
      return PaymentVerification(
        transactionRef: customReference ?? 'PF-SVC-FAILED',
        amountPaid: 0.0,
        status: PaymentStatus.failed,
        isConfirmed: false,
        verifiedAt: DateTime.now(),
        failureReason: 'Insufficient balance or invalid payment amount',
      );
    }

    final prefix = referencePrefix ?? 'PF-SVC-';
    final refCode = customReference ?? '$prefix${DateTime.now().millisecondsSinceEpoch.toString().substring(4)}';
    final request = PaymentRequest(
      transactionRef: refCode,
      amount: amount,
      customerIdentifier: identifier,
      paymentType: category.toLowerCase(),
      description: title,
    );

    PaymentService serviceToUse = _paymentService;
    if (customProvider != null) {
      serviceToUse = PaymentService(
        customProviders: {customProvider.providerType: customProvider},
      );
      serviceToUse.selectProvider(customProvider.providerType);
    } else {
      final effectiveProvider = Env.isMockMode ? PaymentProviderType.mock : providerType;
      serviceToUse.selectProvider(effectiveProvider);
    }

    final verification = await serviceToUse.processPayment(request);

    if (verification.isConfirmed) {
      final newTx = TransactionItem(
        id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        category: category,
        amount: amount,
        timestamp: DateTime.now(),
        isCredit: false,
        status: 'Completed',
        reference: refCode,
        recipientOrSender: identifier,
        transferType: 'Utility Payment',
        token: token,
        narration: narration,
      );

      state = state.copyWith(
        mainBalance: state.mainBalance - amount,
        transactions: [newTx, ...state.transactions],
      );

      NotificationService().showNotification(
        title: 'Utility Payment Successful',
        body: '₦${amount.toStringAsFixed(2)} for $title ($refCode) completed.',
        category: NotificationCategory.transactions,
        payload: {'transactionRef': refCode},
      );
    }

    return verification;
  }

  void setTransactionFilter(String filter) {
    state = state.copyWith(activeFilter: filter);
  }
}

final walletViewModelProvider =
    StateNotifierProvider<WalletViewModel, WalletState>((ref) {
  final repo = ref.watch(walletRepositoryProvider);
  final vm = WalletViewModel(walletRepository: repo);
  ref.listen<AuthState>(authViewModelProvider, (previous, next) {
    if (next.status == AuthStatus.authenticated &&
        previous?.status != AuthStatus.authenticated) {
      vm.fetchWalletData();
    }
  });
  return vm;
});
