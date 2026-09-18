import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/payflow_button.dart';
import '../models/auth_state.dart';
import '../view_models/auth_view_model.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final List<TextEditingController> _pinControllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _pinFocusNodes = List.generate(4, (_) => FocusNode());
  String? _localError;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkStoredIdentityAndRedirect();
    });
  }

  void _checkStoredIdentityAndRedirect() {
    if (!mounted) return;
    final authState = ref.read(authViewModelProvider);
    if (authState.isLoading) return;

    final authRepo = ref.read(authRepositoryProvider);
    final repoPhone = authRepo.getAuthenticatedPhone();
    final repoEmail = authRepo.getSavedEmail();

    final hasPhone = (authState.phoneNumber != null &&
            authState.phoneNumber!.trim().isNotEmpty) ||
        (repoPhone != null && repoPhone.trim().isNotEmpty);
    final hasEmail =
        (authState.email != null && authState.email!.trim().isNotEmpty) ||
            (repoEmail != null && repoEmail.trim().isNotEmpty);

    if (!hasPhone && !hasEmail) {
      try {
        context.go('/sign-in');
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    for (final controller in _pinControllers) {
      controller.dispose();
    }
    for (final node in _pinFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _passcode => _pinControllers.map((c) => c.text).join();

  String? _getMaskedIdentifier({String? email, String? phone}) {
    if (email != null && email.trim().isNotEmpty) {
      final clean = email.trim();
      final parts = clean.split('@');
      if (parts.length == 2 && parts[0].isNotEmpty) {
        final name = parts[0];
        final domain = parts[1];
        final prefix = name.length > 3 ? name.substring(0, 3) : name;
        return '$prefix***@$domain';
      }
      return clean.length >= 3 ? '${clean.substring(0, 3)}***' : '$clean***';
    }

    if (phone != null && phone.trim().isNotEmpty) {
      final clean = phone.replaceAll(RegExp(r'\s+'), '');
      if (clean.length >= 10) {
        return '${clean.substring(0, 4)} *** ${clean.substring(clean.length - 3)}';
      }
      return '$clean***';
    }

    return null;
  }

  String _getInitials(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return 'U';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  void _onDigitChanged(String value, int index) {
    final digits = value.replaceAll(RegExp(r'\D'), '');

    // Support multi-digit paste or direct test enterText input
    if (digits.length > 1) {
      for (int i = 0; i < 4; i++) {
        if (i < digits.length) {
          _pinControllers[i].text = digits[i];
        } else {
          _pinControllers[i].clear();
        }
      }
      if (_passcode.length == 4) {
        _pinFocusNodes[3].unfocus();
        _onLogin();
      } else if (digits.length < 4) {
        _pinFocusNodes[digits.length].requestFocus();
      }
      return;
    }

    if (value.isNotEmpty) {
      _pinControllers[index].text = value.substring(value.length - 1);
      if (index < 3) {
        _pinFocusNodes[index + 1].requestFocus();
      } else {
        _pinFocusNodes[index].unfocus();
      }
    } else if (index > 0) {
      _pinFocusNodes[index - 1].requestFocus();
    }

    // Auto-submit when exactly 4 digits are completed
    if (_passcode.length == 4) {
      _onLogin();
    }
  }

  Future<void> _handleSwitchAccount() async {
    await ref.read(authViewModelProvider.notifier).switchAccount();
    if (mounted) {
      try {
        context.go('/sign-in');
      } catch (_) {
        try {
          context.push('/sign-in');
        } catch (_) {}
      }
    }
  }

  Future<void> _onLogin() async {
    if (_isSubmitting) return;
    setState(() => _localError = null);
    final code = _passcode;

    if (code.length != 4) {
      setState(() => _localError = 'Please enter your 4-digit passcode.');
      return;
    }

    final authState = ref.read(authViewModelProvider);
    final authRepo = ref.read(authRepositoryProvider);
    final identifier = authState.phoneNumber ??
        authRepo.getAuthenticatedPhone() ??
        authState.email ??
        authRepo.getSavedEmail();

    _isSubmitting = true;
    final success = await ref
        .read(authViewModelProvider.notifier)
        .loginWithPin(code, identifier: identifier);
    _isSubmitting = false;

    if (success && mounted) {
      try {
        context.go('/home');
      } catch (_) {}
    }
  }

  Future<void> _onBiometricLogin() async {
    setState(() => _localError = null);
    final success = await ref
        .read(authViewModelProvider.notifier)
        .loginWithBiometrics();

    if (success && mounted) {
      try {
        context.go('/home');
      } catch (_) {}
    }
  }

  void _onSignUp() {
    try {
      context.push('/face-capture');
    } catch (_) {
      try {
        context.go('/face-capture');
      } catch (_) {}
    }
  }

  void _showQuickLinksModal() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF141724) : AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spaceLg,
              vertical: AppDimensions.spaceMd,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.2)
                          : AppColors.borderLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceLg),
                Text(
                  'Quick Links',
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceMd),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.support_agent_rounded, color: AppColors.primary),
                  ),
                  title: Text(
                    'Customer Support',
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    ),
                  ),
                  subtitle: Text(
                    '24/7 dedicated assistance',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : AppColors.textSecondaryLight,
                    ),
                  ),
                  onTap: () => Navigator.pop(modalContext),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.location_on_outlined, color: AppColors.primary),
                  ),
                  title: Text(
                    'Find ATM / Branch',
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    ),
                  ),
                  subtitle: Text(
                    'Locate nearest PayFlow agent',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : AppColors.textSecondaryLight,
                    ),
                  ),
                  onTap: () => Navigator.pop(modalContext),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.help_outline_rounded, color: AppColors.primary),
                  ),
                  title: Text(
                    'Help & FAQ',
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    ),
                  ),
                  subtitle: Text(
                    'Common banking answers',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : AppColors.textSecondaryLight,
                    ),
                  ),
                  onTap: () => Navigator.pop(modalContext),
                ),
                const SizedBox(height: AppDimensions.spaceMd),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showForgotPasscodeModal() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF141724) : AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.spaceLg,
              AppDimensions.spaceMd,
              AppDimensions.spaceLg,
              AppDimensions.spaceXl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.2)
                          : AppColors.borderLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceLg),
                Text(
                  'Forgot Passcode',
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceSm),
                Text(
                  'Reset your 4-digit passcode securely using your registered phone number and OTP verification.',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceLg),
                PayFlowButton(
                  text: 'Reset Passcode',
                  onPressed: () {
                    Navigator.pop(modalContext);
                    _handleSwitchAccount();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authViewModelProvider, (previous, next) {
      if (previous?.isLoading == true && !next.isLoading) {
        _checkStoredIdentityAndRedirect();
      }
    });

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authViewModelProvider);

    if (authState.isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final authRepo = ref.watch(authRepositoryProvider);
    final rawName = authState.fullName ?? authRepo.getSavedFullName();
    final hasName = rawName != null && rawName.trim().isNotEmpty;
    final rawPhone = authState.phoneNumber ?? authRepo.getAuthenticatedPhone();
    final hasPhone = rawPhone != null && rawPhone.trim().isNotEmpty;
    final rawEmail = authState.email ?? authRepo.getSavedEmail();
    final hasEmail = rawEmail != null && rawEmail.trim().isNotEmpty;

    final hasStoredIdentity = hasPhone || hasEmail;
    if (!hasStoredIdentity) {
      // Identity absent: return minimal view while redirecting to /sign-in
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final displayName = hasName ? rawName.trim() : 'User';
    final initials = _getInitials(displayName);
    final maskedIdentifier = _getMaskedIdentifier(
      email: rawEmail,
      phone: rawPhone,
    );

    final errorMessage = _localError ?? authState.errorMessage;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          key: const Key('back_button'),
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppDimensions.spaceSm),
            child: IconButton(
              key: const Key('quick_links_button'),
              tooltip: 'Quick links',
              onPressed: _showQuickLinksModal,
              icon: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceVariantLight,
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : AppColors.borderLight,
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.bolt_rounded,
                  color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: AppDimensions.spaceSm),

                      // 1. Circular Gradient Avatar Badge
                      Center(
                        child: Container(
                          key: const Key('user_avatar_badge'),
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFE91E63),
                                AppColors.primary,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.35),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spaceMd),

                      // 2. Greeting Header Layout
                      Text(
                        'Welcome Back!',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.7)
                              : AppColors.textSecondaryLight,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        displayName,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spaceLg),

                      // 3. Account Pill & Switcher
                      if (maskedIdentifier != null) ...[
                        Container(
                          key: const Key('account_pill'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.spaceMd,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: isDark ? AppColors.borderDark : AppColors.borderLight,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.account_circle_outlined,
                                  color: AppColors.primary,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: AppDimensions.spaceSm),
                              Text(
                                maskedIdentifier,
                                style: TextStyle(
                                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(width: AppDimensions.spaceXs),
                              IconButton(
                                key: const Key('switch_account_button'),
                                tooltip: 'Switch Account',
                                icon: const Icon(
                                  Icons.sync_alt_rounded,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: _handleSwitchAccount,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spaceXl),
                      ],

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
                        const SizedBox(height: AppDimensions.spaceMd),
                      ],

                      // 4. Enter 4-Digit Passcode Label
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Enter 4-Digit Passcode',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.8)
                                : AppColors.textPrimaryLight,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spaceMd),

                      // 4 Discrete Passcode Digit Boxes
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(
                          4,
                          (index) => SizedBox(
                            width: 64,
                            height: 64,
                            child: TextFormField(
                              key: index == 0
                                  ? const Key('password_pin_input')
                                  : Key('pin_box_$index'),
                              controller: _pinControllers[index],
                              focusNode: _pinFocusNodes[index],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              obscureText: true,
                              obscuringCharacter: '•',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                              ),
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(index == 0 ? 4 : 1),
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: isDark
                                    ? AppColors.surfaceDark
                                    : AppColors.surfaceLight,
                                contentPadding: EdgeInsets.zero,
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppDimensions.radiusMd),
                                  borderSide: BorderSide(
                                    color: isDark
                                        ? AppColors.borderDark
                                        : AppColors.borderLight,
                                    width: 1.5,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppDimensions.radiusMd),
                                  borderSide: BorderSide(
                                    color: isDark
                                        ? AppColors.borderDark
                                        : AppColors.borderLight,
                                    width: 1.5,
                                  ),
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
                              onChanged: (val) => _onDigitChanged(val, index),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spaceSm),

                      // Forgot Passcode Action
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          key: const Key('forgot_pin_button'),
                          onPressed: _showForgotPasscodeModal,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Forgot Passcode?',
                            semanticsLabel: 'Forgot 4-digit passcode',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: AppDimensions.spaceXl),

                      // 5. Primary "Log in" Action Button
                      PayFlowButton(
                        key: const Key('login_button'),
                        text: 'Log In',
                        isLoading: authState.isLoading,
                        onPressed: _onLogin,
                      ),

                      const SizedBox(height: AppDimensions.spaceXl),

                      // 6. Bottom Biometric Unlock Action
                      InkWell(
                        key: const Key('biometric_login_button'),
                        onTap: _onBiometricLogin,
                        borderRadius: BorderRadius.circular(32),
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                blurRadius: 14,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.fingerprint_rounded,
                              color: AppColors.primary,
                              size: 34,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Biometric Unlock',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.5)
                              : AppColors.textSecondaryLight,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const Spacer(),

                      // 7. Footer Link: Don't have an account? Sign up
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppDimensions.spaceMd),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account?",
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.7)
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              key: const Key('sign_up_button'),
                              onTap: _onSignUp,
                              child: Text(
                                'Sign up',
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
            );
          },
        ),
      ),
    );
  }
}
