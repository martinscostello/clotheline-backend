import 'package:flutter/material.dart';

class WaterDroplet extends StatelessWidget {
  final double size;
  final bool isDark;

  const WaterDroplet({
    super.key,
    required this.size,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Refraction Simulation using Gradient
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(isDark ? 0.3 : 0.8), // Highlight
            Colors.white.withOpacity(0.0), // Clear center
            Colors.black.withOpacity(isDark ? 0.4 : 0.1), // Shadow/Depth
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
        boxShadow: [
          // Drop Shadow
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(2, 4),
          ),
          // Inner Glow (Highlight)
          BoxShadow(
            color: Colors.white.withOpacity(isDark ? 0.1 : 0.4),
            blurRadius: 4,
            offset: const Offset(-2, -2),
            // inset: true - Not supported natively, simulating with gradient decoration on container
          ),
        ],
        // Border ring for surface tension
        border: Border.all(
          color: Colors.white.withOpacity(isDark ? 0.2 : 0.4),
          width: 1,
        ),
      ),
      child: Container(
        // Internal reflection spot
        margin: EdgeInsets.all(size * 0.2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
             center: const Alignment(-0.5, -0.5),
             radius: 0.5,
             colors: [
               Colors.white.withOpacity(isDark ? 0.4 : 0.7),
               Colors.transparent,
             ],
          ),
        ),
      ),
    );
  }
}
