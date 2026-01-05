import 'dart:ui';
import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final double blur;
  final double opacity;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final BoxBorder? border;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.blur = 15.0, // Standard frost
    this.opacity = 0.05, // Very clear
    this.borderRadius = 20.0, // Medical/Tech roundness (not too round)
    this.padding,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur + 2, sigmaY: blur + 2), // Helper to ensure increase if passed manually, or just change default
        child: Container(
          width: width,
          height: height,
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: (isDark ? Colors.black : Colors.white).withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(borderRadius),
            // Crisp, single-line border for dimensions
            border: border ?? Border.all(
              color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.3), 
              width: 0.5
            ),
             // Subtle gradient for surface sheen
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: isDark ? 0.05 : 0.2),
                Colors.white.withValues(alpha: 0.0),
              ],
            ),
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(
              shadows: [
                // Inverted glow: Dark Mode (White Text) -> Black Glow. Light Mode (Black Text) -> White Glow.
                Shadow(
                  color: isDark ? Colors.black.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.8),
                  blurRadius: 4,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
