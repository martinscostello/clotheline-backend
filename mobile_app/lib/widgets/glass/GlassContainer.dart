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
  final Color? color;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.blur = 10.0, // Reduced for performance
    this.opacity = 0.05, // Very clear
    this.borderRadius = 20.0, // Medical/Tech roundness (not too round)
    this.padding,
    this.border,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // PERFORMANCE FIX: 
    // Removed BackdropFilter (Blur) entirely as it causes massive GPU overhead and overheating 
    // on physical devices when used in lists/grids. 
    // Falling back to simple transparency (fake glass).
    
    return Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color ?? (isDark ? Colors.black : Colors.white).withValues(alpha: opacity * 2), // Double opacity for visibility since blur is gone
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
    );
  }
}
