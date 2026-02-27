import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'WaterDroplet.dart';

class FigmaBackground extends StatelessWidget {
  final Widget child;

  const FigmaBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Spec: Gradient Backgrounds
    final bgStart = isDark ? AppTheme.darkBgStart : AppTheme.lightBgStart;
    final bgEnd = isDark ? AppTheme.darkBgEnd : AppTheme.lightBgEnd;

    return Stack(
      children: [
        // 1. Base Gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [bgStart, bgEnd],
            ),
          ),
        ),

        // 2. Floating Water Droplets (Simulated Motion)
        // Large Droplets
        _buildAnimatedDroplet(top: 100, left: 20, size: 60, isDark: isDark, delay: 0),
        _buildAnimatedDroplet(top: 400, right: 30, size: 80, isDark: isDark, delay: 1000),
        _buildAnimatedDroplet(bottom: 150, left: 80, size: 40, isDark: isDark, delay: 2000),
        
        // Small Droplets
        _buildAnimatedDroplet(top: 250, right: 100, size: 20, isDark: isDark, delay: 500),
        _buildAnimatedDroplet(bottom: 300, left: 40, size: 25, isDark: isDark, delay: 1500),

        // 3. Main Content
        child,
      ],
    );
  }

  Widget _buildAnimatedDroplet({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double size,
    required bool isDark,
    required int delay,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: WaterDroplet(size: size, isDark: isDark)
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .moveY(begin: 0, end: -30, duration: 6.seconds, delay: delay.ms, curve: Curves.easeInOut)
          .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 4.seconds),
    );
  }
}
