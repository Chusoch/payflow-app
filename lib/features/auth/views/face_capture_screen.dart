import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/payflow_button.dart';

enum FaceCaptureStep {
  checklist,
  capturing,
  success,
}

class FaceCaptureScreen extends ConsumerStatefulWidget {
  const FaceCaptureScreen({super.key});

  @override
  ConsumerState<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends ConsumerState<FaceCaptureScreen>
    with SingleTickerProviderStateMixin {
  FaceCaptureStep _currentStep = FaceCaptureStep.checklist;
  bool _termsAccepted = false;
  bool _isProcessingCapture = false;

  late AnimationController _checkAnimController;
  late Animation<double> _checkScaleAnimation;

  @override
  void initState() {
    super.initState();
    _checkAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _checkScaleAnimation = CurvedAnimation(
      parent: _checkAnimController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _checkAnimController.dispose();
    super.dispose();
  }

  void _onStartCapture() {
    setState(() {
      _currentStep = FaceCaptureStep.capturing;
    });
  }

  Future<void> _triggerCapture() async {
    if (_isProcessingCapture) return;

    setState(() {
      _isProcessingCapture = true;
    });

    // Simulate liveness detection analysis
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    setState(() {
      _isProcessingCapture = false;
      _currentStep = FaceCaptureStep.success;
    });
    _checkAnimController.forward(from: 0.0);
  }

  void _onAddBvnNin() {
    context.go('/bvn-nin-verification');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F19),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () {
            if (_currentStep == FaceCaptureStep.capturing) {
              setState(() {
                _currentStep = FaceCaptureStep.checklist;
              });
            } else if (_currentStep == FaceCaptureStep.success) {
              setState(() {
                _currentStep = FaceCaptureStep.capturing;
              });
            } else {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/onboarding');
              }
            }
          },
        ),
        title: Text(
          _currentStep == FaceCaptureStep.checklist
              ? 'Identity Verification'
              : _currentStep == FaceCaptureStep.capturing
                  ? 'Face Verification'
                  : 'Verification Complete',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: _buildCurrentStepView(),
        ),
      ),
    );
  }

  Widget _buildCurrentStepView() {
    switch (_currentStep) {
      case FaceCaptureStep.checklist:
        return _buildChecklistView();
      case FaceCaptureStep.capturing:
        return _buildCapturingView();
      case FaceCaptureStep.success:
        return _buildSuccessView();
    }
  }

  // ---------------------------------------------------------------------------
  // STEP 1: Checklist & Guidelines
  // ---------------------------------------------------------------------------
  Widget _buildChecklistView() {
    return LayoutBuilder(
      key: const ValueKey('checklist_view'),
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceLg),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - AppDimensions.spaceMd,
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppDimensions.spaceXs),
                  const Text(
                    "Let's do your capturing",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'We will take a quick photo of your face to verify your identity against official records.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spaceMd),

                  // Hero Visual Badge
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.12),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          width: 2,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.face_rounded,
                          size: 42,
                          color: AppColors.primaryLight,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spaceMd),

                  // Checklist Items
                  const _ChecklistCard(
                    icon: Icons.light_mode_rounded,
                    iconColor: Color(0xFFFBBF24),
                    title: 'Good lighting',
                    subtitle:
                        "Make sure you're in a well lit area with no harsh shadows or glare.",
                  ),
                  const SizedBox(height: AppDimensions.spaceSm),

                  const _ChecklistCard(
                    icon: Icons.center_focus_strong_rounded,
                    iconColor: Color(0xFF38BDF8),
                    title: 'Look straight',
                    subtitle:
                        'Hold your phone at eye level and look directly into the camera.',
                  ),
                  const SizedBox(height: AppDimensions.spaceSm),

                  const _ChecklistCard(
                    icon: Icons.face_retouching_natural_rounded,
                    iconColor: Color(0xFFA78BFA),
                    title: 'Remove accessories',
                    subtitle:
                        'Remove eyeglasses, hats, caps, or any coverings obstructing your face.',
                  ),
                  const SizedBox(height: AppDimensions.spaceMd),

                  // Terms and Conditions Checkbox
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _termsAccepted = !_termsAccepted;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.spaceSm,
                        vertical: 4,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Checkbox(
                            value: _termsAccepted,
                            onChanged: (val) {
                              setState(() {
                                _termsAccepted = val ?? false;
                              });
                            },
                            activeColor: AppColors.primary,
                            checkColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'I agree to the Terms and Conditions and consent to facial biometric verification.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),
                  const SizedBox(height: AppDimensions.spaceLg),

                  // Continue Button
                  PayFlowButton(
                    text: 'Continue',
                    onPressed: _termsAccepted ? _onStartCapture : null,
                  ),
                  const SizedBox(height: AppDimensions.spaceMd),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 2: Capture Viewport / Circular Indicator
  // ---------------------------------------------------------------------------
  Widget _buildCapturingView() {
    return Center(
      key: const ValueKey('capturing_view'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Face Capturing',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppDimensions.spaceXs),
            Text(
              'Align your face inside the circle and hold still.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.space2Xl),

            // Circular Viewfinder with Outer Ring
            Stack(
              alignment: Alignment.center,
              children: [
                // Outer glowing pulse ring
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isProcessingCapture
                          ? AppColors.income.withValues(alpha: 0.5)
                          : AppColors.primary.withValues(alpha: 0.4),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _isProcessingCapture
                            ? AppColors.income.withValues(alpha: 0.2)
                            : AppColors.primary.withValues(alpha: 0.15),
                        blurRadius: 28,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),

                // Inner camera viewport container
                Container(
                  width: 230,
                  height: 230,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF161A2B),
                    border: Border.all(
                      color: _isProcessingCapture
                          ? AppColors.income
                          : AppColors.primaryLight,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: _isProcessingCapture
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 44,
                                height: 44,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.income,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppDimensions.spaceMd),
                              Text(
                                'Analyzing liveness...',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.face_retouching_natural_rounded,
                                size: 90,
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                              const SizedBox(height: AppDimensions.spaceXs),
                              Text(
                                'Look directly here',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.space2Xl),

            // Capture CTA Trigger
            PayFlowButton(
              text: _isProcessingCapture ? 'Processing...' : 'Capture Photo',
              isLoading: _isProcessingCapture,
              onPressed: _isProcessingCapture ? null : _triggerCapture,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 3: Animated Success State
  // ---------------------------------------------------------------------------
  Widget _buildSuccessView() {
    return Center(
      key: const ValueKey('success_view'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated Green Check Badge
            ScaleTransition(
              scale: _checkScaleAnimation,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.income.withValues(alpha: 0.15),
                  border: Border.all(
                    color: AppColors.income,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.income.withValues(alpha: 0.3),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 68,
                    color: AppColors.income,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spaceXl),

            const Text(
              'Face capturing successful',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spaceSm),

            Text(
              'Your facial biometrics have been captured and securely encrypted for identity verification.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.space2Xl),

            // Primary Action: Add BVN/NIN
            PayFlowButton(
              text: 'Add BVN/NIN',
              onPressed: _onAddBvnNin,
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Checklist Card Component
// -----------------------------------------------------------------------------
class _ChecklistCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _ChecklistCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      decoration: BoxDecoration(
        color: const Color(0xFF161A2B),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.07),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withValues(alpha: 0.15),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 22,
            ),
          ),
          const SizedBox(width: AppDimensions.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
