import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/payflow_button.dart';
import '../view_models/auth_view_model.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final TextEditingController _identifierController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _localError;

  @override
  void dispose() {
    _identifierController.dispose();
    super.dispose();
  }

  String _normalizeIdentifier(String input) {
    final clean = input.trim();
    if (clean.contains('@')) {
      return clean.toLowerCase();
    }
    // Remove whitespace and dashes
    final digitsOnly = clean.replaceAll(RegExp(r'[\s\-()]'), '');
    if (digitsOnly.startsWith('+234')) {
      return digitsOnly;
    }
    if (digitsOnly.startsWith('0') && digitsOnly.length == 11) {
      return '+234${digitsOnly.substring(1)}';
    }
    if (digitsOnly.length == 10) {
      return '+234$digitsOnly';
    }
    return digitsOnly;
  }

  Future<void> _onContinue() async {
    setState(() => _localError = null);
    final rawInput = _identifierController.text.trim();
    if (rawInput.isEmpty) {
      setState(() => _localError = 'Please enter your email or phone number.');
      return;
    }

    final normalized = _normalizeIdentifier(rawInput);
    final isEmail = normalized.contains('@');

    if (isEmail) {
      final emailRegex = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(normalized)) {
        setState(() => _localError = 'Please enter a valid email address.');
        return;
      }
    } else {
      // Must have at least 10 digits
      final digitCount = normalized.replaceAll(RegExp(r'[^\d]'), '').length;
      if (digitCount < 10) {
        setState(() => _localError = 'Please enter a valid Nigerian phone number.');
        return;
      }
    }

    // Submit identifier to trigger OTP / verification challenge
    final phoneOrId = isEmail
        ? normalized
        : normalized.replaceFirst(RegExp(r'^\+234'), '0');

    final success = await ref
        .read(authViewModelProvider.notifier)
        .submitPhoneNumber(phoneOrId, isLogin: true);

    if (success && mounted) {
      context.push('/otp-verification');
    }
  }

  void _onCreateAccount() {
    try {
      context.push('/face-capture');
    } catch (_) {
      try {
        context.go('/face-capture');
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authViewModelProvider);
    final errorMessage = _localError ?? authState.errorMessage;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          key: const Key('sign_in_back_button'),
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
          ),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              try {
                context.go('/onboarding');
              } catch (_) {}
            }
          },
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceLg),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - kToolbarHeight,
                ),
                child: IntrinsicHeight(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppDimensions.spaceSm),

                        // Header Icon Badge
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withValues(alpha: 0.12),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.login_rounded,
                              color: AppColors.primary,
                              size: 26,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spaceLg),

                        // Headline & Subtitle
                        Text(
                          'Sign In to PayFlow',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: isDark ? Colors.white : AppColors.textPrimaryLight,
                            fontWeight: FontWeight.bold,
                            fontSize: 26,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Enter your registered email address or phone number to continue.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.7)
                                : AppColors.textSecondaryLight,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.space2Xl),

                        // Error Banner
                        if (errorMessage != null) ...[
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
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: AppColors.expense,
                                  size: 18,
                                ),
                                const SizedBox(width: AppDimensions.spaceSm),
                                Expanded(
                                  child: Text(
                                    errorMessage,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AppColors.expense,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spaceLg),
                        ],

                        // Adaptive Identifier Input: Email or Phone Number
                        Text(
                          'Email or Phone Number',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.8)
                                : AppColors.textPrimaryLight,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spaceXs),
                        TextFormField(
                          key: const Key('sign_in_identifier_input'),
                          controller: _identifierController,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.textPrimaryLight,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: 'e.g. user@example.com or 08012345678',
                            hintStyle: TextStyle(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.3)
                                  : AppColors.textSecondaryLight.withValues(alpha: 0.6),
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                            prefixIcon: Icon(
                              Icons.alternate_email_rounded,
                              color: isDark ? Colors.white54 : AppColors.textSecondaryLight,
                              size: 20,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                              borderSide: BorderSide(
                                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                              borderSide: BorderSide(
                                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppDimensions.spaceMd,
                              vertical: 16,
                            ),
                          ),
                          onFieldSubmitted: (_) => _onContinue(),
                        ),

                        const SizedBox(height: AppDimensions.space2Xl),

                        // Primary CTA: Continue
                        PayFlowButton(
                          key: const Key('sign_in_continue_button'),
                          text: 'Continue',
                          isLoading: authState.isLoading,
                          onPressed: _onContinue,
                        ),

                        const Spacer(),

                        // Secondary Link: New to PayFlow? Create Account
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppDimensions.spaceMd),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'New to PayFlow?',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.7)
                                      : AppColors.textSecondaryLight,
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                key: const Key('create_account_button'),
                                onTap: _onCreateAccount,
                                child: Text(
                                  'Create Account',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spaceSm),
                      ],
                    ),
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
