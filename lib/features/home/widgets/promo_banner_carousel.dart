import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_dimensions.dart';
import '../models/promo_banner.dart';

class PromoBannerCarousel extends StatefulWidget {
  final List<PromoBanner> banners;
  final int currentIndex;
  final ValueChanged<int>? onPageChanged;
  final Duration autoSlideDuration;

  const PromoBannerCarousel({
    super.key,
    required this.banners,
    this.currentIndex = 0,
    this.onPageChanged,
    this.autoSlideDuration = const Duration(seconds: 4),
  });

  @override
  State<PromoBannerCarousel> createState() => _PromoBannerCarouselState();
}

class _PromoBannerCarouselState extends State<PromoBannerCarousel> {
  late final PageController _pageController;
  Timer? _autoSlideTimer;
  bool _isUserInteracting = false;
  late int _activePage;

  @override
  void initState() {
    super.initState();
    _activePage = widget.currentIndex;
    _pageController = PageController(initialPage: _activePage);
    _startAutoSlide();
  }

  @override
  void didUpdateWidget(PromoBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex &&
        widget.currentIndex != _activePage &&
        _pageController.hasClients) {
      _activePage = widget.currentIndex;
      _pageController.animateToPage(
        _activePage,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _startAutoSlide() {
    _stopAutoSlide();
    if (widget.banners.length <= 1) return;
    _autoSlideTimer = Timer.periodic(widget.autoSlideDuration, (_) {
      if (_isUserInteracting || !mounted || !_pageController.hasClients) return;
      final nextPage = (_activePage + 1) % widget.banners.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  void _stopAutoSlide() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = null;
  }

  void _onPointerDown() {
    setState(() => _isUserInteracting = true);
    _stopAutoSlide();
  }

  void _onPointerUp() {
    setState(() => _isUserInteracting = false);
    _startAutoSlide();
  }

  @override
  void dispose() {
    _stopAutoSlide();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Column(
      children: [
        Listener(
          onPointerDown: (_) => _onPointerDown(),
          onPointerUp: (_) => _onPointerUp(),
          onPointerCancel: (_) => _onPointerUp(),
          child: SizedBox(
            height: 138,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.banners.length,
              onPageChanged: (index) {
                setState(() => _activePage = index);
                widget.onPageChanged?.call(index);
              },
              itemBuilder: (context, index) {
                final banner = widget.banners[index];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                    gradient: LinearGradient(
                      colors: banner.gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: banner.gradientColors.first.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        if (banner.actionRoute != null) {
                          context.go(banner.actionRoute!);
                        }
                      },
                      borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.spaceMd,
                          vertical: AppDimensions.spaceSm + 2,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                physics: const ClampingScrollPhysics(),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppDimensions.spaceSm,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(
                                          AppDimensions.radiusFull,
                                        ),
                                      ),
                                      child: Text(
                                        banner.badgeText,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: AppDimensions.spaceSm - 2),
                                    Text(
                                      banner.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      banner.subtitle,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.88),
                                        fontSize: 12,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: AppDimensions.spaceSm),
                            Container(
                              padding: const EdgeInsets.all(AppDimensions.spaceSm + 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                banner.icon,
                                color: Colors.white,
                                size: AppDimensions.iconLg,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spaceSm),

        // Carousel Page Indicators (Animated Dots)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.banners.length,
            (index) {
              final isActive = index == _activePage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isActive ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive
                      ? theme.primaryColor
                      : theme.textTheme.bodySmall?.color?.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
