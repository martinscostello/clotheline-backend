import 'dart:ui';
import 'package:flutter/material.dart';

class LaundryGlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double opacity;
  final double blur;
  final EdgeInsetsGeometry? padding;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;

  const LaundryGlassCard({
    super.key,
    required this.child,
    this.borderRadius = 20.0,
    this.opacity = 0.1,
    this.blur = 12.0, // Increased for a deeper frosted look
    this.padding,
    this.border,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!isDark) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: boxShadow ?? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            padding: padding ?? const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(borderRadius),
              border: border ?? Border.all(color: Colors.black.withValues(alpha: 0.05), width: 0.5),
            ),
            child: child,
          ),
        ),
      );
    }

    // Base Color: White tint for dark mode
    const tintColor = Colors.white;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: boxShadow ?? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container( // Main Layer Container
            decoration: BoxDecoration(
              color: tintColor.withValues(alpha: opacity * 0.3), 
              borderRadius: BorderRadius.circular(borderRadius),
              border: border ?? Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 0.5,
              ),
            ),
            child: Stack(
              children: [
                // 1. Edge Highlight (FLUSH WITH EDGES)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(borderRadius),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        stops: const [0.0, 0.2, 0.4],
                        colors: [
                          Colors.white.withValues(alpha: 0.08),
                          Colors.white.withValues(alpha: 0.01),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // 2. Content Layer (With Padding)
                Padding(
                  padding: padding ?? const EdgeInsets.all(12),
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
