import 'package:flutter/material.dart';


class LiquidBackground extends StatelessWidget {
  final Widget child;

  const LiquidBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Robust Linear Background (Safe for Tablets/Old GPUs)
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0F2027), // Deep Dark Blue
                Color(0xFF203A43), // Tealish
                Color(0xFF2C5364), // Cyanish
              ],
            ),
          ),
        ),
        
        // Optional: Subtle Mesh Pattern Image if available, otherwise just gradient
        // For now, keeping it clean to solve pixelation.
        
        // 2. Subtle Top-Right Glow (Linear, Safe)
        Positioned(
          top: -150,
          right: -50,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient( // Linear is safer than Radial on some SKIA versions
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF00C6FF).withOpacity(0.1),
                  Colors.transparent
                ],
              ),
            ),
          ),
        ),

        // Main Content
        child,
      ],
    );
  }
}
