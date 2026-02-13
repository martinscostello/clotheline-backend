import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class FloatingObjectsBackground extends StatelessWidget {
  final Widget child;

  const FloatingObjectsBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // In light mode, objects are faint dark gray. In dark mode, faint white.
    final objectColor = isDark 
        ? Colors.white.withValues(alpha: 0.05) 
        : Colors.black.withValues(alpha: 0.05);

    // Background is handled by Scaffold, but we can add a very subtle gradient for depth
    // based on the theme mode.
    final gradientColors = isDark
        ? [Colors.black, const Color(0xFF1A1A2E)]
        : [const Color(0xFFF9F9F9), const Color(0xFFE0E0E0)];

    return Stack(
      children: [
        // 1. Subtle Gradient Background Loop
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
          ),
        ),

        // 2. Floating Objects (Clothes/Shoes/Hangers)
        // More items, varying speeds for "Alive" feel
        _buildFloatingObject(Icons.checkroom, 100, -50, -50, 4000, objectColor),
        _buildFloatingObject(Icons.local_laundry_service, 80, 200, -80, 6000, objectColor),
        _buildFloatingObject(Icons.dry_cleaning, 120, null, -100, 5000, objectColor, right: -50),
        _buildFloatingObject(Icons.shopping_bag, 60, 400, null, 7000, objectColor, right: 20),
        _buildFloatingObject(Icons.iron, 90, 600, -60, 5500, objectColor),
        
        // Extra "Alive" items
        _buildFloatingObject(Icons.wash, 70, 150, 50, 8000, objectColor),
        _buildFloatingObject(Icons.water_drop, 40, 300, 200, 4500, objectColor),
        _buildFloatingObject(Icons.soap, 50, 500, 100, 6500, objectColor),

        // 3. Child Content
        child,
      ],
    );
  }

  Widget _buildFloatingObject(
      IconData icon, 
      double size, 
      double? top, 
      double? left, 
      int durationMs, 
      Color color,
      {double? right, double? bottom}) {
    
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Icon(
        icon,
        size: size,
        color: color,
      )
      .animate(onPlay: (controller) => controller.repeat(reverse: true))
      .moveY(begin: 0, end: 40, duration: Duration(milliseconds: durationMs), curve: Curves.easeInOutSine) // More organic curve
      .rotate(begin: -0.05, end: 0.05, duration: Duration(milliseconds: durationMs + 2000)) // Gentle swaying
      .scale(begin: const Offset(1,1), end: const Offset(1.1, 1.1), duration: Duration(milliseconds: durationMs + 1000)), // Branding breathing
    );
  }
}
