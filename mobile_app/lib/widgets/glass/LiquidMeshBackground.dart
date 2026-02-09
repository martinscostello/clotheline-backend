import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';

class LiquidMeshBackground extends StatelessWidget {
  final Widget child;

  const LiquidMeshBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Define the "Lava" colors based on theme
    final blobColors = isDark 
      ? [
          const Color(0xFF4A00E0), // Deep Purple
          const Color(0xFF8E2DE2), // Violet
          const Color(0xFF00C6FF), // Cyan
        ]
      : [
          const Color(0xFFE0C3FC), // Soft Purple
          const Color(0xFF8EC5FC), // Soft Blue
          const Color(0xFFC2E9FB), // Cyan Tint
        ];

    return Stack(
      children: [
        // 1. Base Background Color
        Container(color: Theme.of(context).scaffoldBackgroundColor),

        // 2. Moving Blobs (The "Liquid")
        // Blob 1: Top Left -> Floating
        _buildAnimatedBlob(
           color: blobColors[0],
           size: 400,
           offsetX: -100, offsetY: -100,
           duration: 8.seconds,
        ),
        
        // Blob 2: Bottom Right -> Floating
        _buildAnimatedBlob(
           color: blobColors[1],
           size: 350,
           offsetX: 200, offsetY: 500,
           duration: 10.seconds,
           isReverse: true,
        ),

        // Blob 3: Center -> Breathing
        _buildAnimatedBlob(
           color: blobColors[2],
           size: 300,
           offsetX: 100, offsetY: 200,
           duration: 12.seconds,
        ),

        // 3. Blur Mesh (blends the blobs together)
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 60.0, sigmaY: 60.0),
          child: Container(color: Colors.transparent),
        ),

        // 4. Noise/Grain texture (Optional, adds "premium" feel - using low opacity white noise if we had an asset, skipping for now)

        // 5. Content
        child,
      ],
    );
  }

  Widget _buildAnimatedBlob({
    required Color color, 
    required double size, 
    required double offsetX, 
    required double offsetY,
    required Duration duration,
    bool isReverse = false,
  }) {
    return Positioned(
      top: offsetY,
      left: offsetX,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.6),
        ),
      )
      .animate(onPlay: (controller) => controller.repeat(reverse: true))
      .scale(
        begin: const Offset(0.8, 0.8), 
        end: const Offset(1.2, 1.2), 
        duration: duration,
        curve: Curves.easeInOutQuad,
      )
      .move(
        begin: Offset(isReverse ? 50 : -50, isReverse ? -50 : 50),
        end: Offset(isReverse ? -50 : 50, isReverse ? 50 : -50),
        duration: duration * 1.5,
      ),
    );
  }
}
