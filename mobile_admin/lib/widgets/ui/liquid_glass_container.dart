import 'dart:ui';
import 'package:flutter/material.dart';

/// A reusable, high-fidelity "Liquid Glass" container.
/// 
/// Features:
/// - Full Refraction (Center Zoom 1.06x, Blur 2.0)
/// - Subtle Concave Rim (Inner White Shadow)
/// - Depth Shadow (Back Black Shadow)
/// - Fully responsive zoom origin (anchored to screen center)
class LiquidGlassContainer extends StatelessWidget {
  final Widget child;
  final double radius;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;

  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.radius = 24.0,
    this.width,
    this.height,
    this.padding,
    this.blur = 2.0,
  });

  final double blur;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.15);
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.loose,
        children: [
          // Removing RepaintBoundary to ensure BackdropFilter context is preserved during scroll
          Positioned.fill(
              child: Stack(
                children: [
                   // 0. Shadow Layer (Depth)
                   Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(radius),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2), // Tuned Intensity
                            blurRadius: 15,
                            spreadRadius: 1,
                            offset: const Offset(0, 8), 
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 1. Liquid Glass Lens (Refraction)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(radius),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(color: glassColor),
                      ),
                    ),
                  ),

                  // 2. Subtle Concave Rim (Inner Reflection)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _InnerShadowPainter(
                          radius: radius,
                          color: Colors.white.withValues(alpha: 0.2), // Tuned Opacity
                          blur: 2, // Matches Lens Blur
                          offset: const Offset(0, 0), // Uniform
                          strokeWidth: 1.2, // Tuned Spread
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ),

          // 3. Child Content
          Container(
            padding: padding,
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Custom Painter for the Internal Rim Light
class _InnerShadowPainter extends CustomPainter {
  final double radius;
  final double strokeWidth;
  final Color color;
  final double blur;
  final Offset offset;

  _InnerShadowPainter({
    required this.radius,
    this.strokeWidth = 2,
    this.color = const Color(0xB3FFFFFF),
    this.blur = 1,
    this.offset = const Offset(2, 2),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    canvas.save();
    canvas.clipRRect(rrect);
    
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 2 // Double width so half is clipped
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);

    canvas.drawRRect(rrect.shift(offset), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
