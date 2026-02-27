import 'package:flutter/material.dart';

class LaundryGlassBackground extends StatelessWidget {
  final Widget child;

  const LaundryGlassBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (!isDark) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFFECECEC), // Match AppTheme.lightBgStart
        child: child,
      );
    }

    // "Fresh" Colors for Dark Mode
    final bgColors = [const Color(0xFF0F2027), const Color(0xFF203A43), const Color(0xFF2C5364)]; // Deep Ocean

    // Bubbles/Icons Color
    final bubbleColor = Colors.white.withValues(alpha: 0.05);
    final iconColor = Colors.white.withValues(alpha: 0.05);

    return Stack(
      fit: StackFit.expand, // [FIX] Ensure stack fills available space
      children: [
        // 1. Background
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: bgColors,
            ),
          ),
        ),

        // 2. Rising Glass Bubbles & Icons
        IgnorePointer( // [FIX] Global ignore for background decorations
          child: Stack(
            children: [
              _buildBubble(size: 60, left: 50, speedMs: 4000, color: bubbleColor),
              _buildBubble(size: 120, left: 200, speedMs: 7000, color: bubbleColor),
              _buildBubble(size: 40, left: 300, speedMs: 5000, color: bubbleColor),
              _buildBubble(size: 80, left: 150, speedMs: 6000, color: bubbleColor),
              _buildBubble(size: 100, left: 350, speedMs: 8000, color: bubbleColor),

              _buildFloatingIcon(Icons.checkroom, 150, 50, 100, iconColor),
              _buildFloatingIcon(Icons.dry_cleaning, 280, 300, 200, iconColor),
              _buildFloatingIcon(Icons.local_laundry_service, 400, 80, 150, iconColor),
              _buildFloatingIcon(Icons.iron, 100, 300, 250, iconColor),
              _buildFloatingIcon(Icons.wash, 500, 200, 300, iconColor),
            ],
          ),
        ),

        // 4. Content
        child,
      ],
    );
  }

  Widget _buildBubble({required double size, required double left, required int speedMs, required Color color}) {
    return Positioned(
      bottom: 20, // Static position near bottom
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
      ),
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
      ),
    );
  }
}
