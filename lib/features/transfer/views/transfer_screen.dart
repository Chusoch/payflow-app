import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/env.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/payflow_button.dart';
import '../../../core/widgets/payflow_card.dart';
import '../../../core/widgets/payflow_text_field.dart';
import '../../auth/view_models/auth_view_model.dart';
import '../../home/models/transaction_item.dart';
import '../../profile/view_models/profile_view_model.dart';
import '../../wallet/view_models/wallet_view_model.dart';
import '../view_models/transfer_view_model.dart';
import '../widgets/transfer_result_sheet.dart';
import '../widgets/transfer_review_sheet.dart';

class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String? _recipientError;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    _recipientController.addListener(_onRecipientChanged);
  }

  void _onRecipientChanged() {
    final text = _recipientController.text.trim();
    if (text.isEmpty) {
      ref.read(transferViewModelProvider.notifier).resetRecipient();
      if (mounted && _recipientError != null) {
        setState(() => _recipientError = null);
      }
    }
  }

  @override
  void dispose() {
    _recipientController.removeListener(_onRecipientChanged);
    _recipientController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _resetScreen() {
    _recipientController.clear();
    _amountController.clear();
    _noteController.clear();
    ref.read(transferViewModelProvider.notifier).resetTransferState();
    if (mounted) {
      setState(() {
        _recipientError = null;
        _amountError = null;
      });
    }
  }

  void _onBeneficiarySelected(Beneficiary ben) {
    _recipientController.text = ben.accountOrPhone;
    setState(() {
      _recipientError = null;
    });

    final notifier = ref.read(transferViewModelProvider.notifier);
    if (ben.bankName.contains('PayFlow')) {
      notifier.setTransferType('PayFlow User');
      notifier.resolvePayFlowUser(ben.accountOrPhone);
    } else {
      notifier.setTransferType('Bank Account');
      if (ben.bankCode != null) {
        notifier.setSelectedBank(ben.bankName, ben.bankCode!);
        notifier.resolveBankAccount(ben.accountOrPhone, ben.bankCode!);
      }
    }
  }

  Future<void> _showBankPickerBottomSheet(BuildContext context) async {
    final transferState = ref.read(transferViewModelProvider);
    final transferNotifier = ref.read(transferViewModelProvider.notifier);
    final banks = transferState.availableBanks;

    final selectedBank = await showModalBottomSheet<BankItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);
            final filteredBanks = searchQuery.isEmpty
                ? banks
                : banks
                    .where((b) => b.name.toLowerCase().contains(searchQuery.toLowerCase()))
                    .toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppDimensions.radiusLg),
                ),
              ),
              padding: const EdgeInsets.all(AppDimensions.spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spaceMd),
                  Text(
                    'Select Destination Bank',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppDimensions.spaceMd),
                  TextField(
                    autofocus: false,
                    decoration: InputDecoration(
                      hintText: 'Search bank name...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceMd),
                    ),
                    onChanged: (val) {
                      setModalState(() {
                        searchQuery = val.trim();
                      });
                    },
                  ),
                  const SizedBox(height: AppDimensions.spaceMd),
                  Expanded(
                    child: filteredBanks.isEmpty
                        ? const Center(
                            child: Text('No banks match your search', style: TextStyle(color: Colors.grey)),
                          )
                        : ListView.separated(
                            itemCount: filteredBanks.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final bank = filteredBanks[index];
                              final isSelected = bank.code == transferState.selectedBankCode;
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                  child: const Icon(Icons.account_balance_outlined, color: AppColors.primary, size: 18),
                                ),
                                title: Text(
                                  bank.name,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? AppColors.primary : null,
                                  ),
                                ),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                                    : null,
                                onTap: () => Navigator.of(context).pop(bank),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (selectedBank != null) {
      transferNotifier.setSelectedBank(selectedBank.name, selectedBank.code);
      final recipient = _recipientController.text.trim();
      if (recipient.length == 10) {
        transferNotifier.resolveBankAccount(recipient, selectedBank.code);
      }
    }
  }

  Future<void> _validateAndReview() async {
    setState(() {
      _recipientError = null;
      _amountError = null;
    });

    final transferState = ref.read(transferViewModelProvider);
    final walletState = ref.read(walletViewModelProvider);
    final transferNotifier = ref.read(transferViewModelProvider.notifier);

    final recipient = _recipientController.text.trim();
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);

    bool hasError = false;

    // Recipient Validation
    if (recipient.isEmpty) {
      setState(() => _recipientError = 'Please enter a recipient phone or account number');
      hasError = true;
    } else if (transferState.selectedTransferType == 'PayFlow User' &&
        (recipient.length < 10 || double.tryParse(recipient) == null)) {
      setState(() => _recipientError = 'Enter a valid 10-11 digit phone or account number');
      hasError = true;
    } else if (transferState.selectedTransferType == 'Bank Account' &&
        (recipient.length != 10 || double.tryParse(recipient) == null)) {
      setState(() => _recipientError = 'Account number must be 10 digits');
      hasError = true;
    }

    // Amount Validation
    if (amount == null || amount <= 0) {
      setState(() => _amountError = 'Please enter a valid amount greater than ₦0');
      hasError = true;
    } else if (amount > walletState.mainBalance) {
      setState(() => _amountError =
          'Insufficient balance. Available: ₦${walletState.mainBalance.toStringAsFixed(2)}');
      hasError = true;
    }

    if (hasError) return;

    transferNotifier.setAmount(amount);

    // Resolve name prior to opening review sheet
    String? resolvedName = transferState.verifiedRecipient ?? transferState.resolvedAccountName;
    if (transferState.selectedTransferType == 'PayFlow User') {
      resolvedName ??= await transferNotifier.resolvePayFlowUser(recipient);
      if (resolvedName == null) {
        setState(() {
          _recipientError = ref.read(transferViewModelProvider).errorMessage ??
              'No PayFlow user found with this number';
        });
        return;
      }
    } else {
      resolvedName ??= await transferNotifier.resolveBankAccount(
          recipient, transferState.selectedBankCode);
      if (resolvedName == null) {
        setState(() {
          _recipientError = ref.read(transferViewModelProvider).errorMessage ??
              'Could not resolve bank account details';
        });
        return;
      }
    }

    if (!mounted) return;

    final String verifiedName = resolvedName;

    // Open Transfer Review Sheet
    TransferReviewSheet.show(
      context: context,
      recipientName: verifiedName,
      recipientIdentifier: recipient,
      transferType: transferState.selectedTransferType,
      bankName: transferState.selectedTransferType == 'Bank Account'
          ? transferState.selectedBank
          : 'PayFlow Account',
      amount: amount!,
      narration: _noteController.text.trim(),
      onConfirm: () => _executeTransfer(
        recipientName: verifiedName,
        recipientIdentifier: recipient,
        amount: amount,
      ),
    );
  }

  Future<void> _executeTransfer({
    required String recipientName,
    required String recipientIdentifier,
    required double amount,
  }) async {
    final transferState = ref.read(transferViewModelProvider);
    final walletNotifier = ref.read(walletViewModelProvider.notifier);
    final transferNotifier = ref.read(transferViewModelProvider.notifier);
    final refCode = 'PF-TRF-${DateTime.now().millisecondsSinceEpoch.toString().substring(4)}';

    transferNotifier.setErrorMessage(null);
    transferNotifier.setIsProcessing(true);

    try {
      if (transferState.selectedTransferType == 'PayFlow User') {
        if (!Env.isMockMode) {
          final response = await defaultApiClient.post(
            '/v1/wallet/transfer',
            body: {
              'toPhone': recipientIdentifier,
              'amount_kobo': (amount * 100).toInt(),
              'reference': refCode,
              'recipientName': recipientName,
            },
          );

          if (response.statusCode != 200 && response.statusCode != 201) {
            String errorMsg = 'Transfer failed (HTTP ${response.statusCode})';
            try {
              final bodyJson = jsonDecode(response.body);
              errorMsg = bodyJson['error']?.toString() ?? bodyJson['message']?.toString() ?? errorMsg;
            } catch (_) {}
            transferNotifier.setErrorMessage(errorMsg);
            transferNotifier.setIsProcessing(false);
            return;
          }

          walletNotifier.addTransaction(
            TransactionItem(
              id: refCode,
              title: 'Transfer to $recipientName',
              category: 'Transfer',
              amount: amount,
              timestamp: DateTime.now(),
              isCredit: false,
              status: 'Completed',
              reference: refCode,
              recipientOrSender: recipientName,
              transferType: 'PayFlow User',
            ),
          );
          await walletNotifier.refreshWallet();
        } else {
          walletNotifier.sendMoney(
            recipient: recipientName,
            transferType: 'PayFlow User',
            amount: amount,
            note: _noteController.text.trim(),
          );
        }
      } else {
        // Bank Account Transfer
        if (!Env.isMockMode) {
          final response = await defaultApiClient.post(
            '/v1/transfers/bank',
            body: {
              'accountNumber': recipientIdentifier,
              'bankCode': transferState.selectedBankCode,
              'bankName': transferState.selectedBank,
              'amount': (amount * 100).toInt(),
              'amount_kobo': (amount * 100).toInt(),
              'narration': _noteController.text.trim(),
              'accountName': recipientName,
              'reference': refCode,
            },
          );

          if (response.statusCode != 200 && response.statusCode != 201) {
            String errorMsg = 'Transfer failed (HTTP ${response.statusCode})';
            try {
              final bodyJson = jsonDecode(response.body);
              errorMsg = bodyJson['error']?.toString() ?? bodyJson['message']?.toString() ?? errorMsg;
            } catch (_) {}
            transferNotifier.setErrorMessage(errorMsg);
            transferNotifier.setIsProcessing(false);
            return;
          }

          walletNotifier.addTransaction(
            TransactionItem(
              id: refCode,
              title: 'Transfer to $recipientName',
              category: 'Transfer',
              amount: amount,
              timestamp: DateTime.now(),
              isCredit: false,
              status: 'Completed',
              reference: refCode,
              recipientOrSender: recipientName,
              transferType: 'Bank Transfer',
            ),
          );
          await walletNotifier.refreshWallet();
        } else {
          walletNotifier.sendMoney(
            recipient: recipientName,
            transferType: 'Bank Account',
            amount: amount,
            note: _noteController.text.trim(),
            bankName: transferState.selectedBank,
          );
        }
      }
    } catch (e) {
      final errorStr = e.toString().replaceAll('Exception: ', '');
      transferNotifier.setErrorMessage('Network connection error: $errorStr');
      transferNotifier.setIsProcessing(false);
      return;
    }

    transferNotifier.setIsProcessing(false);

    // Persist Beneficiary to SharedPreferences
    transferNotifier.saveBeneficiary(
      Beneficiary(
        id: 'b_${DateTime.now().millisecondsSinceEpoch}',
        name: recipientName,
        accountOrPhone: recipientIdentifier,
        bankName: transferState.selectedTransferType == 'Bank Account'
            ? transferState.selectedBank
            : 'PayFlow Account',
        bankCode: transferState.selectedBankCode,
      ),
    );

    if (!mounted) return;

    final authState = ref.read(authViewModelProvider);
    final profileState = ref.read(profileViewModelProvider);
    final senderName = (authState.fullName?.trim().isNotEmpty == true)
        ? authState.fullName!.trim()
        : ((authState.user?.fullName?.trim().isNotEmpty == true)
            ? authState.user!.fullName!.trim()
            : (profileState.fullName.trim().isNotEmpty ? profileState.fullName.trim() : 'You'));

    // Show Success Result Sheet
    TransferResultSheet.show(
      context: context,
      isSuccess: true,
      recipientName: recipientName,
      amount: amount,
      reference: refCode,
      narration: _noteController.text.trim(),
      senderName: senderName,
      onDone: () {
        _resetScreen();
        walletNotifier.refreshWallet();
        context.go('/wallet');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transferState = ref.watch(transferViewModelProvider);
    final transferNotifier = ref.read(transferViewModelProvider.notifier);
    final walletState = ref.watch(walletViewModelProvider);
    final verifiedName = transferState.verifiedRecipient ?? transferState.resolvedAccountName;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Money'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Retry-on-Error Banner
              if (transferState.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppDimensions.spaceMd),
                  decoration: BoxDecoration(
                    color: AppColors.expense.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    border: Border.all(color: AppColors.expense.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.expense),
                      const SizedBox(width: AppDimensions.spaceSm),
                      Expanded(
                        child: Text(
                          transferState.errorMessage!,
                          style: const TextStyle(fontSize: 12, color: AppColors.expense),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          final recipient = _recipientController.text.trim();
                          final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
                          final resolvedName = verifiedName ?? recipient;
                          _executeTransfer(
                            recipientName: resolvedName,
                            recipientIdentifier: recipient,
                            amount: amount,
                          );
                        },
                        child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceLg),
              ],

              // Transfer Mode Switcher
              Container(
                padding: const EdgeInsets.all(AppDimensions.spaceXs),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? AppColors.surfaceVariantDark
                      : AppColors.surfaceVariantLight,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Row(
                  children: [
                    _TypeTab(
                      label: 'PayFlow User',
                      isSelected:
                          transferState.selectedTransferType == 'PayFlow User',
                      onTap: () {
                        transferNotifier.setTransferType('PayFlow User');
                        setState(() {
                          _recipientError = null;
                        });
                      },
                    ),
                    _TypeTab(
                      label: 'Bank Account',
                      isSelected:
                          transferState.selectedTransferType == 'Bank Account',
                      onTap: () {
                        transferNotifier.setTransferType('Bank Account');
                        setState(() {
                          _recipientError = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.spaceLg),

              if (transferState.recentBeneficiaries.isNotEmpty) ...[
                // Recent Beneficiaries Header
                Text(
                  'Recent Recipients',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceMd),

                SizedBox(
                  height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: transferState.recentBeneficiaries.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: AppDimensions.spaceMd),
                    itemBuilder: (context, index) {
                      final ben = transferState.recentBeneficiaries[index];
                      return GestureDetector(
                        onTap: () => _onBeneficiarySelected(ben),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.15),
                              child: Text(
                                ben.name.isNotEmpty ? ben.name.substring(0, 1) : 'P',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ben.name.split(' ').first,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceLg),
              ],

              // Form Inputs Card
              PayFlowCard(
                padding: const EdgeInsets.all(AppDimensions.spaceLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bank Picker (in Bank Account Mode)
                    if (transferState.selectedTransferType == 'Bank Account') ...[
                      InkWell(
                        onTap: () => _showBankPickerBottomSheet(context),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Select Destination Bank',
                            prefixIcon: const Icon(Icons.account_balance_outlined),
                            suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                            ),
                          ),
                          child: Text(
                            transferState.selectedBank,
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spaceMd),
                    ],

                    PayFlowTextField(
                      label: transferState.selectedTransferType == 'PayFlow User'
                          ? 'Phone / Account Number'
                          : '10-Digit Account Number',
                      hintText: transferState.selectedTransferType == 'PayFlow User'
                          ? 'e.g. 08012345678'
                          : 'Enter 10-digit NUBAN',
                      controller: _recipientController,
                      errorText: _recipientError,
                      keyboardType: TextInputType.number,
                      prefixIcon: Icon(
                        transferState.selectedTransferType == 'PayFlow User'
                            ? Icons.phone_android_rounded
                            : Icons.badge_outlined,
                      ),
                      onChanged: (val) {
                        final text = val.trim();
                        if (text.isEmpty) {
                          transferNotifier.resetRecipient();
                          if (_recipientError != null) {
                            setState(() => _recipientError = null);
                          }
                          return;
                        }
                        if (_recipientError != null) {
                          setState(() => _recipientError = null);
                        }
                        if (transferState.selectedTransferType == 'PayFlow User') {
                          if (text.length >= 10) {
                            transferNotifier.resolvePayFlowUser(text);
                          } else {
                            transferNotifier.resetRecipient();
                          }
                        } else if (transferState.selectedTransferType == 'Bank Account') {
                          if (text.length == 10) {
                            transferNotifier.resolveBankAccount(text, transferState.selectedBankCode);
                          } else {
                            transferNotifier.resetRecipient();
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 4),

                    // Name Resolution Badge
                    if (transferState.isResolvingAccount) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppDimensions.spaceXs),
                        child: Row(
                          children: [
                            SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 8),
                            Text('Resolving account details...', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                          ],
                        ),
                      ),
                    ] else if (verifiedName != null && _recipientController.text.trim().isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: AppDimensions.spaceXs),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceSm, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.income.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                            border: Border.all(color: AppColors.income.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: AppColors.income, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Account Verified: $verifiedName',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.income,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else if (transferState.errorMessage != null &&
                        _recipientError == null &&
                        _recipientController.text.trim().isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: AppDimensions.spaceXs),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceSm, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.expense.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                            border: Border.all(color: AppColors.expense.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: AppColors.expense, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  transferState.errorMessage!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.expense,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: AppDimensions.spaceMd),

                    PayFlowTextField(
                      label: 'Amount (₦)',
                      hintText: '0.00',
                      keyboardType: TextInputType.number,
                      controller: _amountController,
                      errorText: _amountError,
                      prefixIcon: const Icon(Icons.numbers_rounded),
                      onChanged: (val) {
                        if (_amountError != null) {
                          setState(() => _amountError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Available Balance: ₦${walletState.mainBalance.toStringAsFixed(2)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 11,
                          color: AppColors.income,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spaceMd),

                    PayFlowTextField(
                      label: 'Narration (Optional)',
                      hintText: 'What is this for?',
                      controller: _noteController,
                      prefixIcon: const Icon(Icons.notes_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.spaceXl),

              // Send Money Action Button
              PayFlowButton(
                text: 'Continue Transfer',
                icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                onPressed: _validateAndReview,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeTab extends StatelessWidget {
  const _TypeTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: AppDimensions.spaceSm + 2),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                    )
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? theme.colorScheme.onSurface
                    : theme.textTheme.bodyMedium?.color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
