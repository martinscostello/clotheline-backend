import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';

class LaundryGlassBackground extends StatelessWidget {
  final Widget child;

  const LaundryGlassBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // "Fresh" Colors
    final bgColors = isDark 
      ? [const Color(0xFF0F2027), const Color(0xFF203A43), const Color(0xFF2C5364)] // Deep Ocean
      : [Colors.white, Colors.white]; // Pure White for Light Mode

    // Bubbles/Icons Color
    final bubbleColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05);
    final iconColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.1); // Stronger black for visibility

    return Stack(
      children: [
        // 1. Background
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: bgColors,
            ),
          ),
        ),

        // 2. Rising Glass Bubbles
        _buildBubble(size: 60, left: 50, speedMs: 4000, color: bubbleColor),
        _buildBubble(size: 120, left: 200, speedMs: 7000, color: bubbleColor),
        _buildBubble(size: 40, left: 300, speedMs: 5000, color: bubbleColor),
        _buildBubble(size: 80, left: 150, speedMs: 6000, color: bubbleColor),
        _buildBubble(size: 100, left: 350, speedMs: 8000, color: bubbleColor),

        // 3. Floating Laundry Elements (Black Shapes in Light Mode)
        _buildFloatingIcon(Icons.checkroom, 150, 50, 100, iconColor),
        _buildFloatingIcon(Icons.dry_cleaning, 280, 300, 200, iconColor),
        _buildFloatingIcon(Icons.local_laundry_service, 400, 80, 150, iconColor),
        _buildFloatingIcon(Icons.iron, 100, 300, 250, iconColor),
        _buildFloatingIcon(Icons.wash, 500, 200, 300, iconColor),

        // 4. Content
        child,
      ],
    );
  }

  Widget _buildBubble({required double size, required double left, required int speedMs, required Color color}) {
    return Positioned(
      bottom: -150, // Start below screen
      left: left,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // Bubble Gradient
          gradient: RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.1),
              Colors.white.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 1.0],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
        ),
      )
      .animate(onPlay: (controller) => controller.repeat())
      .moveY(begin: 0, end: -1000, duration: Duration(milliseconds: speedMs)) // Float Up
      .fadeIn(duration: 500.ms)
      .fadeOut(delay: (speedMs - 500).ms, duration: 500.ms), // Fade out at top
    );
  }

  Widget _buildFloatingIcon(IconData icon, double top, double left, int delay, Color color) {
    return Positioned(
      top: top,
      left: left,
      child: Icon(
        icon,
        size: 80, // Slightly smaller pattern
        color: color,
      )
      .animate(onPlay: (controller) => controller.repeat(reverse: true))
      .moveY(begin: 0, end: 20, duration: 4.seconds, curve: Curves.easeInOut)
      .rotate(begin: -0.05, end: 0.05, duration: 5.seconds),
    );
  }
}
