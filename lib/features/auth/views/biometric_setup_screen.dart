import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/payflow_button.dart';
import '../view_models/auth_view_model.dart';

class BiometricSetupScreen extends ConsumerWidget {
  const BiometricSetupScreen({super.key});

  Future<void> _enableBiometrics(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(authViewModelProvider.notifier);
    await notifier.setupBiometrics(true);
    if (context.mounted) {
      context.go('/home');
    }
  }

  Future<void> _skipBiometrics(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(authViewModelProvider.notifier);
    await notifier.setupBiometrics(false);
    if (context.mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authViewModelProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => _skipBiometrics(context, ref),
            child: Text(
              'Skip',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.spaceMd),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceLg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.fingerprint_rounded,
                  size: 72,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppDimensions.space2Xl),
              Text(
                'Enable Biometric Login',
                textAlign: TextAlign.center,
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 26,
                ),
              ),
              const SizedBox(height: AppDimensions.spaceMd),
              Text(
                'Use Face ID or Fingerprint for faster, seamless, and secure login without typing your PIN every time.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondaryLight,
                  height: 1.5,
                ),
              ),
              const Spacer(),

              PayFlowButton(
                text: 'Enable Biometrics',
                isLoading: authState.isLoading,
                icon: const Icon(Icons.fingerprint, color: Colors.white),
                onPressed: () => _enableBiometrics(context, ref),
              ),
              const SizedBox(height: AppDimensions.spaceMd),

              PayFlowButton(
                text: 'Maybe Later',
                variant: PayFlowButtonVariant.text,
                onPressed: () => _skipBiometrics(context, ref),
              ),
              const SizedBox(height: AppDimensions.spaceLg),
            ],
          ),
        ),
      ),
    );
  }
}
