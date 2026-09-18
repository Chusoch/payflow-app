import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/payflow_button.dart';
import '../models/auth_state.dart';
import '../view_models/auth_view_model.dart';

class ConfirmPinScreen extends ConsumerStatefulWidget {
  const ConfirmPinScreen({super.key});

  @override
  ConsumerState<ConfirmPinScreen> createState() => _ConfirmPinScreenState();
}

class _ConfirmPinScreenState extends ConsumerState<ConfirmPinScreen> {
  String _confirmPin = '';

  void _onKeyPress(String val) {
    if (_confirmPin.length < 4) {
      setState(() {
        _confirmPin += val;
      });
      if (_confirmPin.length == 4) {
        _verifyAndSubmitPin();
      }
    }
  }

  void _onBackspace() {
    if (_confirmPin.isNotEmpty) {
      setState(() {
        _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
      });
    }
  }

  Future<void> _verifyAndSubmitPin() async {
    final authViewModel = ref.read(authViewModelProvider.notifier);
    final success = await authViewModel.confirmPin(_confirmPin);

    if (success && mounted) {
      final authState = ref.read(authViewModelProvider);
      if (authState.status == AuthStatus.awaitingProfileSetup) {
        context.go('/profile-setup');
      } else if (authState.status == AuthStatus.awaitingBiometrics) {
        context.go('/biometric-setup');
      } else {
        context.go('/home');
      }
    } else {
      setState(() {
        _confirmPin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authViewModelProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceLg),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: AppDimensions.spaceSm),
                      Text(
                        'Confirm Your PIN',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spaceXs),
                      Text(
                        'Re-enter your 4-digit PIN to confirm.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spaceLg),

                      if (authState.errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.spaceMd,
                            vertical: AppDimensions.spaceSm,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.expense.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                          ),
                          child: Text(
                            authState.errorMessage!,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.expense,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spaceLg),
                      ],

                      // 4 PIN Dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          4,
                          (index) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: index < _confirmPin.length
                                  ? AppColors.primary
                                  : AppColors.borderLight,
                              border: Border.all(
                                color: index < _confirmPin.length
                                    ? AppColors.primary
                                    : AppColors.borderLight,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),

                      _buildKeypad(theme),
                      const SizedBox(height: AppDimensions.spaceMd),

                      PayFlowButton(
                        text: 'Confirm PIN',
                        isLoading: authState.isLoading,
                        isDisabled: _confirmPin.length != 4,
                        onPressed: _verifyAndSubmitPin,
                      ),
                      const SizedBox(height: AppDimensions.spaceLg),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildKeypad(ThemeData theme) {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'backspace'],
    ];

    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((key) {
              if (key.isEmpty) {
                return const SizedBox(width: 64, height: 64);
              }
              if (key == 'backspace') {
                return InkWell(
                  onTap: _onBackspace,
                  borderRadius: BorderRadius.circular(32),
                  child: Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.backspace_outlined,
                      size: 24,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                );
              }
              return InkWell(
                onTap: () => _onKeyPress(key),
                borderRadius: BorderRadius.circular(32),
                child: Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceVariantLight,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    key,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
