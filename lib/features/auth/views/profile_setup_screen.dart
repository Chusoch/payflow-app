import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/payflow_button.dart';
import '../../../core/widgets/payflow_text_field.dart';
import '../models/auth_state.dart';
import '../view_models/auth_view_model.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final authState = ref.read(authViewModelProvider);
    if (authState.fullName != null && authState.fullName!.trim().isNotEmpty) {
      _nameController.text = authState.fullName!.trim();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_formKey.currentState?.validate() ?? false) {
      final notifier = ref.read(authViewModelProvider.notifier);
      final success = await notifier.submitProfile(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
      );

      if (success && mounted) {
        final authState = ref.read(authViewModelProvider);
        if (authState.status == AuthStatus.awaitingBiometrics) {
          context.go('/biometric-setup');
        } else {
          context.go('/home');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authViewModelProvider);
    final isVerified = authState.isKycVerified &&
        (authState.fullName != null && authState.fullName!.trim().isNotEmpty);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceLg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppDimensions.spaceSm),
                Text(
                  'What should we call you?',
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 26,
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceSm),
                Text(
                  'Please enter your legal full name for payment receipts and identity verification.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryLight,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceXl),

                if (authState.errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spaceMd,
                      vertical: AppDimensions.spaceSm + 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.expense.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    ),
                    child: Text(
                      authState.errorMessage!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.expense,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spaceLg),
                ],

                PayFlowTextField(
                  key: const Key('profile_name_field'),
                  controller: _nameController,
                  label: 'Full Name',
                  hintText: 'e.g. Chukwuma Ugobueze',
                  prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.primary),
                  keyboardType: TextInputType.name,
                  autofocus: !isVerified,
                  readOnly: isVerified,
                  suffixIcon: isVerified
                      ? Padding(
                          padding: const EdgeInsets.only(right: 12.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.income.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.income.withValues(alpha: 0.35),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: AppColors.income,
                                      size: 14,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Verified',
                                      style: TextStyle(
                                        color: AppColors.income,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      : null,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Full name is required';
                    }
                    if (value.trim().length < 2) {
                      return 'Name must be at least 2 characters';
                    }
                    return null;
                  },
                ),
                if (isVerified) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.lock_rounded, size: 12, color: AppColors.income),
                      const SizedBox(width: 4),
                      Text(
                        'Verified via identity database (Locked)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.income,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppDimensions.spaceLg),

                PayFlowTextField(
                  controller: _emailController,
                  label: 'Email Address (Optional)',
                  hintText: 'e.g. chukwuma@example.com',
                  prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primary),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                      if (!emailRegex.hasMatch(value.trim())) {
                        return 'Please enter a valid email address';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDimensions.spaceSm),
                Text(
                  'Your email will receive instant transaction receipts and account recovery alerts.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondaryLight,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: AppDimensions.space2Xl),

                PayFlowButton(
                  text: 'Continue',
                  isLoading: authState.isLoading,
                  onPressed: _handleSubmit,
                ),
                const SizedBox(height: AppDimensions.spaceLg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
