import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/payflow_button.dart';
import '../view_models/auth_view_model.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingItem> _pages = const [
    OnboardingItem(
      title: 'Instant Transfers\nZero Hidden Charges',
      subtitle:
          'Send and receive money seamlessly across all Nigerian banks with instant settlement and 99.9% uptime.',
      icon: Icons.swap_horizontal_circle_rounded,
      highlightTag: 'REAL-TIME SETTLEMENT',
    ),
    OnboardingItem(
      title: 'Pay Bills & Utilities\nIn One Single Tap',
      subtitle:
          'Recharge airtime, buy data bundles, pay electricity disco tokens, and renew cable TV subscriptions effortlessly.',
      icon: Icons.receipt_long_rounded,
      highlightTag: 'AUTOMATED TOKENS',
    ),
    OnboardingItem(
      title: 'Bank-Grade Security\nBiometric Protection',
      subtitle:
          'State-of-the-art liveness facial recognition, transaction PINs, and encrypted multi-factor authentication.',
      icon: Icons.shield_rounded,
      highlightTag: 'CBN REGULATED',
    ),
  ];

  void _onGetStarted() {
    ref.read(authViewModelProvider.notifier).completeOnboarding();
    context.go('/face-capture');
  }

  void _onLogIn() {
    ref.read(authViewModelProvider.notifier).completeOnboarding();
    final authState = ref.read(authViewModelProvider);
    final authRepo = ref.read(authRepositoryProvider);
    final hasSavedUser = (authState.phoneNumber != null && authState.phoneNumber!.isNotEmpty) ||
        (authState.email != null && authState.email!.isNotEmpty) ||
        (authRepo.getAuthenticatedPhone() != null && authRepo.getAuthenticatedPhone()!.isNotEmpty) ||
        (authRepo.getSavedEmail() != null && authRepo.getSavedEmail()!.isNotEmpty);

    if (hasSavedUser) {
      context.go('/login');
    } else {
      context.go('/sign-in');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceLg),
          child: Column(
            children: [
              const SizedBox(height: AppDimensions.spaceMd),

              // Header: Brand Mark
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.15),
                          border: Border.all(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 20,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spaceSm),
                      Text(
                        'PayFlow',
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spaceSm + 2,
                      vertical: AppDimensions.spaceXs,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : AppColors.surfaceVariantLight,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : AppColors.borderLight,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.income,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'CBN Licensed',
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.textPrimaryLight,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppDimensions.spaceMd),

              // Hero Feature Showcase Carousel
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    final item = _pages[index];
                    return Center(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Visual Hero Icon Container
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary.withValues(alpha: 0.12),
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.35),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.2),
                                    blurRadius: 24,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  item.icon,
                                  size: 48,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppDimensions.spaceMd),

                            // Highlight Tag
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppDimensions.spaceSm + 4,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                item.highlightTag,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppDimensions.spaceSm + 2),

                            // Title
                            Text(
                              item.title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: AppDimensions.spaceXs + 2),

                            // Subtitle
                            Text(
                              item.subtitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.7)
                                    : AppColors.textSecondaryLight,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Carousel Indicators (dots)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? AppColors.primary
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.2)
                              : AppColors.borderLight),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.spaceLg),

              // Dual Action Buttons: "Get started" & "Log In"
              PayFlowButton(
                text: 'Get started',
                onPressed: _onGetStarted,
              ),
              const SizedBox(height: AppDimensions.spaceMd),

              PayFlowButton(
                text: 'Log In',
                variant: PayFlowButtonVariant.outline,
                onPressed: _onLogIn,
              ),
              const SizedBox(height: AppDimensions.spaceLg),

              // Regulatory Trust Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.security_rounded,
                    size: 15,
                    color: AppColors.income,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Licensed by the Central Bank of Nigeria (CBN)',
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.6)
                          : AppColors.textSecondaryLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spaceSm),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final String highlightTag;

  const OnboardingItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.highlightTag,
  });
}
