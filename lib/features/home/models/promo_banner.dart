import 'package:flutter/material.dart';

class PromoBanner {
  final String id;
  final String title;
  final String subtitle;
  final String badgeText;
  final List<Color> gradientColors;
  final IconData icon;
  final String? actionRoute;

  const PromoBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.gradientColors,
    required this.icon,
    this.actionRoute,
  });
}
