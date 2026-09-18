import 'package:flutter/material.dart';
import '../constants/app_dimensions.dart';
import '../theme/app_colors.dart';

enum PayFlowCardVariant { standard, gradient, outlined }

class PayFlowCard extends StatelessWidget {
  const PayFlowCard({
    super.key,
    required this.child,
    this.variant = PayFlowCardVariant.standard,
    this.gradient,
    this.padding,
    this.margin,
    this.onTap,
    this.borderRadius,
  });

  final Widget child;
  final PayFlowCardVariant variant;
  final Gradient? gradient;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveRadius = borderRadius ?? AppDimensions.radiusLg;
    final effectivePadding =
        padding ?? const EdgeInsets.all(AppDimensions.spaceMd);

    final isGradient =
        variant == PayFlowCardVariant.gradient || gradient != null;

    Widget content = Container(
      padding: effectivePadding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(effectiveRadius),
        gradient: isGradient
            ? (gradient ?? AppColors.primaryGradient)
            : null,
        color: isGradient
            ? null
            : (variant == PayFlowCardVariant.outlined
                ? Colors.transparent
                : theme.cardTheme.color),
        border: !isGradient
            ? (variant == PayFlowCardVariant.outlined
                ? Border.all(
                    color: theme.brightness == Brightness.dark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
                    width: 1,
                  )
                : Border.all(
                    color: theme.brightness == Brightness.dark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
                    width: 1,
                  ))
            : null,
      ),
      child: child,
    );

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(effectiveRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(effectiveRadius),
          child: content,
        ),
      );
    }

    return content;
  }
}
