import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
          ).animate(onPlay: (controller) => controller.repeat(reverse: true))
              .move(duration: 4000.ms, begin: const Offset(0, 0), end: const Offset(50, 50))
              .scale(duration: 4000.ms, begin: const Offset(1, 1), end: const Offset(1.2, 1.2)),
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
          ).animate(onPlay: (controller) => controller.repeat(reverse: true))
              .move(duration: 5000.ms, begin: const Offset(0, 0), end: const Offset(-40, -60))
              .scale(duration: 5000.ms, begin: const Offset(1, 1), end: const Offset(1.5, 1.5)),
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
          ).animate(onPlay: (controller) => controller.repeat(reverse: true))
              .move(duration: 6000.ms, begin: const Offset(0, 0), end: const Offset(20, -20)),
        ),

        // Main Content
        child,
      ],
    );
  }
}
