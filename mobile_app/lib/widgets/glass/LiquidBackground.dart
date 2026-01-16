import 'package:flutter/material.dart';


class LiquidBackground extends StatelessWidget {
  final Widget child;

  const LiquidBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background Color
        Container(color: const Color(0xFF050510)),

        // Animated Orbs (Simulating Liquid)
        Positioned(
          top: -100,
          left: -100,
          child: Container(
            width: 400,
            height: 400,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0xFF7000FF), Colors.transparent],
              ),
            ),
          ),
        ),

        Positioned(
          bottom: -100,
          right: -50,
          child: Container(
            width: 300,
            height: 300,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0xFF00F0FF), Colors.transparent],
              ),
            ),
          ),
        ),

         Positioned(
          top: 200,
          right: 100,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF00F0FF).withOpacity(0.15)
            ),
          ),
        ),

        // Main Content
        child,
      ],
    );
  }
}
