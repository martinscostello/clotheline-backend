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

  const PremiumNavBar({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
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
    
    return RepaintBoundary(
      child: ScaleTransition(
        scale: _navbarScaleAnimation,
        child: Container(
          margin: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding > 0 ? bottomPadding : 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(35),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                height: 72,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(35),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.12),
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
                            // 1. Liquid Pill Highlight (Telegram Style)
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: isSelected ? 1.0 : 0.0,
                              child: Container(
                                width: 68,
                                height: 60, // Sits close to top/bottom edges
                                decoration: BoxDecoration(
                                  color: isDark 
                                      ? Colors.white.withValues(alpha: 0.08) 
                                      : Colors.black.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(24),
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
                                          size: 24,
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
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}
