import 'dart:ui';
import 'package:flutter/material.dart';

class PremiumNavItem {
  final String label;
  final IconData icon;

  const PremiumNavItem({
    required this.label,
    required this.icon,
  });
}

class PremiumNavBar extends StatefulWidget {
  final int currentIndex;
  final List<PremiumNavItem> items;
  final Function(int) onTap;

  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;

  const PremiumNavBar({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
    this.margin,
    this.borderRadius,
  });

  @override
  State<PremiumNavBar> createState() => _PremiumNavBarState();
}

class _PremiumNavBarState extends State<PremiumNavBar> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late AnimationController _navbarController;
  
  late List<Animation<double>> _scaleAnimations;
  late List<Animation<double>> _bounceAnimations;
  late Animation<double> _navbarScaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeControllers();

    // Global navbar controller (bubble physics)
    _navbarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _navbarScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.96), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.96, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _navbarController, curve: Curves.easeInOut));
  }

  void _initializeControllers() {
    // Individual item controllers (jiggle + liquid transition)
    _controllers = List.generate(
      widget.items.length,
      (index) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 200),
      ),
    );

    _scaleAnimations = _controllers.map((controller) {
      return TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 50),
        TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 50),
      ]).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));
    }).toList();

    _bounceAnimations = _controllers.map((controller) {
      return TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0.0, end: -3.0), weight: 50),
        TweenSequenceItem(tween: Tween(begin: -3.0, end: 0.0), weight: 50),
      ]).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));
    }).toList();
  }

  @override
  void didUpdateWidget(PremiumNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      // Clean up old controllers
      for (var controller in _controllers) {
        controller.dispose();
      }
      _initializeControllers();
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    _navbarController.dispose();
    super.dispose();
  }

  void _handleTap(int index) {
    _navbarController.forward(from: 0.0);
    _controllers[index].forward(from: 0.0);
    widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    // Background Colors (High contrast for dark mode)
    final Color backgroundColor = isDark 
        ? const Color(0xFF1C1C1E).withValues(alpha: 0.9) // Solid charcoal feel
        : Colors.white.withValues(alpha: 0.85); // Airy but visible
    
    const Color activeColor = Color(0xFF007AFF); // Telegram Blue
    
    // Adaptive Inactive Colors (Non-negotiable)
    final Color inactiveColor = isDark ? Colors.white : Colors.black; 
    
    // 4. Adaptive Margin Logic (System Nav Aware)
    // Threshold for Gesture Nav is usually < 45px, Button Nav is > 45px
    final bool isButtonNav = bottomPadding > 45;
    
    final defaultMargin = EdgeInsets.fromLTRB(20, 0, 20, isButtonNav ? bottomPadding : 20);
    
    // If the widget was passed a zero margin (like in Admin) but we are in Button Nav,
    // we MUST provide the padding to avoid falling behind the navbar.
    // However, if we are in Gesture Nav, we allow it to "fall down" to 0 as requested.
    EdgeInsetsGeometry effectiveMargin;
    if (widget.margin == EdgeInsets.zero) {
      effectiveMargin = isButtonNav 
          ? EdgeInsets.only(bottom: bottomPadding) 
          : EdgeInsets.zero;
    } else {
      effectiveMargin = widget.margin ?? defaultMargin;
    }

    final effectiveBorderRadius = widget.borderRadius ?? BorderRadius.circular(35);

    return ScaleTransition(
        scale: _navbarScaleAnimation,
        child: Container(
          margin: effectiveMargin,
          child: ClipRRect(
            borderRadius: effectiveBorderRadius,
            child: isDark 
              ? BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: _buildNavBarContent(isDark, effectiveBorderRadius, backgroundColor, activeColor, inactiveColor),
                )
              : _buildNavBarContent(isDark, effectiveBorderRadius, backgroundColor, activeColor, inactiveColor),
          ),
        ),
    );
  }

  Widget _buildNavBarContent(bool isDark, BorderRadius effectiveBorderRadius, Color backgroundColor, Color activeColor, Color inactiveColor) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: effectiveBorderRadius,
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.5 : 0.08),
            blurRadius: 16,
            spreadRadius: -4,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(widget.items.length, (index) {
          final item = widget.items[index];
          final isSelected = index == widget.currentIndex;

          return Expanded(
            child: GestureDetector(
              onTap: () => _handleTap(index),
              behavior: HitTestBehavior.opaque,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 1. Liquid Pill Highlight (Shape-Aware)
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: isSelected ? 1.0 : 0.0,
                    child: Container(
                      width: 70,
                      height: 62,
                      decoration: BoxDecoration(
                        color: isDark 
                            ? Colors.white.withOpacity(0.1) 
                            : Colors.black.withOpacity(0.05),
                        borderRadius: index == 0
                            ? BorderRadius.only(
                                topLeft: effectiveBorderRadius.topLeft,
                                bottomLeft: effectiveBorderRadius.bottomLeft,
                                topRight: const Radius.circular(20),
                                bottomRight: const Radius.circular(20),
                              )
                            : index == widget.items.length - 1
                                ? BorderRadius.only(
                                    topRight: effectiveBorderRadius.topRight,
                                    bottomRight: effectiveBorderRadius.bottomRight,
                                    topLeft: const Radius.circular(20),
                                    bottomLeft: const Radius.circular(20),
                                  )
                                : BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  
                  // 2. Content (Icon + Label)
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _controllers[index],
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, _bounceAnimations[index].value),
                            child: Transform.scale(
                              scale: _scaleAnimations[index].value,
                              child: Icon(
                                item.icon,
                                color: isSelected ? activeColor : inactiveColor,
                                size: isSelected ? 28 : 22,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          color: isSelected ? activeColor : inactiveColor,
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
