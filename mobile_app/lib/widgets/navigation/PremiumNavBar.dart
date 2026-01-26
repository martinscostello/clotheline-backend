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
  late List<Animation<double>> _scaleAnimations;
  late List<Animation<double>> _bounceAnimations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.items.length,
      (index) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 200),
      ),
    );

    _scaleAnimations = _controllers.map((controller) {
      return TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2), weight: 50),
        TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 50),
      ]).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));
    }).toList();

    _bounceAnimations = _controllers.map((controller) {
      return TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0.0, end: -4.0), weight: 50),
        TweenSequenceItem(tween: Tween(begin: -4.0, end: 0.0), weight: 50),
      ]).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));
    }).toList();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _handleTap(int index) {
    if (index != widget.currentIndex) {
      _controllers[index].forward(from: 0.0);
      widget.onTap(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    // Colors based on Spec
    final Color backgroundColor = isDark 
        ? const Color(0xFF1C1C1E).withValues(alpha: 0.8) // Deep charcoal
        : Colors.white.withValues(alpha: 0.7); // Light blur with white tint
    
    final Color activeColor = const Color(0xFF007AFF); // Brand Blue
    final Color inactiveColor = isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.4);
    
    final Color activeLabelColor = isDark ? Colors.white : activeColor;
    final Color inactiveLabelColor = isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.5);

    return RepaintBoundary(
      child: Container(
        margin: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding > 0 ? bottomPadding : 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                    blurRadius: 12,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
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
                      child: Column(
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
                                    size: 26,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.label,
                            style: TextStyle(
                              color: isSelected ? activeLabelColor : inactiveLabelColor,
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          // Subtle Underline Indicator
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 2,
                            width: isSelected ? 12 : 0,
                            decoration: BoxDecoration(
                              color: activeColor,
                              borderRadius: BorderRadius.circular(1),
                              boxShadow: isSelected ? [
                                BoxShadow(
                                  color: activeColor.withValues(alpha: 0.4),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                )
                              ] : null,
                            ),
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
    );
  }
}
