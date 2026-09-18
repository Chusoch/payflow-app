import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/payflow_badge.dart';
import '../../../core/widgets/payflow_button.dart';
import '../view_models/auth_view_model.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState
    extends ConsumerState<OtpVerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    // Pre-fill dev code '123456' only when backend explicitly returned mode: "mock"
    final otpMode = ref.read(authViewModelProvider).otpMode;
    if (otpMode == 'mock') {
      const devCode = '123456';
      for (int i = 0; i < 6; i++) {
        _controllers[i].text = devCode[i];
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  String get _otpCode =>
      _controllers.map((controller) => controller.text).join();

  Future<void> _verifyOtp() async {
    final code = _otpCode;
    final authViewModel = ref.read(authViewModelProvider.notifier);
    final success = await authViewModel.verifyOtp(code);

    if (success && mounted) {
      final authState = ref.read(authViewModelProvider);
      if (authState.isLoginFlow) {
        context.go('/pin-entry');
      } else {
        context.go('/create-pin');
      }
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'OTP Verification',
                            style: theme.textTheme.displayMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 26,
                            ),
                          ),
                          if (authState.otpMode == 'mock')
                            const PayFlowBadge(
                              label: 'Dev Mode',
                              status: PayFlowBadgeStatus.info,
                            ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.spaceXs),
                      Text(
                        authState.phoneNumber != null && authState.phoneNumber!.isNotEmpty
                            ? (authState.phoneNumber!.startsWith('+')
                                ? 'Enter the 6-digit code sent to ${authState.phoneNumber}'
                                : 'Enter the 6-digit code sent to +234 ${authState.phoneNumber}')
                            : 'Enter the 6-digit verification code sent to your phone',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                      if (authState.otpMode == 'mock') ...[
                        const SizedBox(height: AppDimensions.spaceMd),
                        // Dev hint container
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppDimensions.spaceMd),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.lightbulb_outline_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: AppDimensions.spaceSm),
                              Expanded(
                                child: Text(
                                  'Development OTP Code: 123456',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppDimensions.space2Xl),
                      ] else ...[
                        const SizedBox(height: AppDimensions.spaceXl),
                      ],

                      if (authState.errorMessage != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppDimensions.spaceMd),
                          decoration: BoxDecoration(
                            color: AppColors.expense.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                            border: Border.all(
                              color: AppColors.expense.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            authState.errorMessage!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.expense,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spaceLg),
                      ],

                      // 6 OTP Digit Boxes
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(
                          6,
                          (index) => SizedBox(
                            width: 44,
                            height: 52,
                            child: TextFormField(
                              controller: _controllers[index],
                              focusNode: _focusNodes[index],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(1),
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                contentPadding: EdgeInsets.zero,
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppDimensions.radiusMd),
                                  borderSide:
                                      const BorderSide(color: AppColors.borderLight),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppDimensions.radiusMd),
                                  borderSide: const BorderSide(
                                    color: AppColors.primary,
                                    width: 2,
                                  ),
                                ),
                              ),
                              onChanged: (value) {
                                if (value.isNotEmpty && index < 5) {
                                  _focusNodes[index + 1].requestFocus();
                                } else if (value.isEmpty && index > 0) {
                                  _focusNodes[index - 1].requestFocus();
                                }
                                if (_otpCode.length == 6) {
                                  _verifyOtp();
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.space2Xl),

                      // Countdown / Resend
                      Center(
                        child: authState.canResendOtp
                            ? TextButton(
                                onPressed: () {
                                  ref
                                      .read(authViewModelProvider.notifier)
                                      .resendOtp();
                                },
                                child: Text(
                                  'Resend Code',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : Text(
                                'Resend code in ${authState.otpCountdownSeconds}s',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondaryLight,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                      ),

                      const Spacer(),

                      PayFlowButton(
                        text: 'Verify OTP',
                        isLoading: authState.isLoading,
                        onPressed: _otpCode.length == 6 ? _verifyOtp : null,
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
}
