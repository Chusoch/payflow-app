import 'package:flutter/material.dart';
import '../constants/app_dimensions.dart';
import '../theme/app_colors.dart';

enum PayFlowButtonVariant { primary, secondary, outline, text }

class PayFlowButton extends StatelessWidget {
  const PayFlowButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.variant = PayFlowButtonVariant.primary,
    this.isLoading = false,
    this.isDisabled = false,
    this.icon,
    this.height = AppDimensions.buttonHeight,
    this.isFullWidth = true,
  });

  final String text;
  final VoidCallback? onPressed;
  final PayFlowButtonVariant variant;
  final bool isLoading;
  final bool isDisabled;
  final Widget? icon;
  final double height;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = !isDisabled && !isLoading && onPressed != null;

    final childWidget = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                variant == PayFlowButtonVariant.outline ||
                        variant == PayFlowButtonVariant.text
                    ? theme.primaryColor
                    : Colors.white,
              ),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                icon!,
                const SizedBox(width: AppDimensions.spaceSm),
              ],
              Text(
                text,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          );

    Widget button;

    switch (variant) {
      case PayFlowButtonVariant.primary:
        button = ElevatedButton(
          onPressed: isEnabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            minimumSize: Size(isFullWidth ? double.infinity : 0, height),
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
          ),
          child: childWidget,
        );
        break;

      case PayFlowButtonVariant.secondary:
        button = ElevatedButton(
          onPressed: isEnabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            minimumSize: Size(isFullWidth ? double.infinity : 0, height),
            backgroundColor: AppColors.secondary,
            disabledBackgroundColor: AppColors.secondary.withValues(alpha: 0.5),
          ),
          child: childWidget,
        );
        break;

      case PayFlowButtonVariant.outline:
        button = OutlinedButton(
          onPressed: isEnabled ? onPressed : null,
          style: OutlinedButton.styleFrom(
            minimumSize: Size(isFullWidth ? double.infinity : 0, height),
          ),
          child: childWidget,
        );
        break;

      case PayFlowButtonVariant.text:
        button = TextButton(
          onPressed: isEnabled ? onPressed : null,
          style: TextButton.styleFrom(
            minimumSize: Size(isFullWidth ? double.infinity : 0, height),
          ),
          child: childWidget,
        );
        break;
    }

    return button;
  }
}
