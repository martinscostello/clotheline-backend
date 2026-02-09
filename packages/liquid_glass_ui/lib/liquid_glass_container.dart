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
  final BorderRadius? borderRadius; // New: Custom Border Radius support
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final double opacity;

  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.radius = 24.0,
    this.borderRadius,
    this.width,
    this.height,
    this.padding,
    this.opacity = 1.0, 
    this.blur = 2.0,
    this.color,
  });

  final double blur;

  @override
  Widget build(BuildContext context) {
    // Determine effective border radius
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(radius);

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.loose,
        children: [
          // 0. Shadow Layer
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: effectiveBorderRadius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2 * opacity), 
                    blurRadius: 15,
                    spreadRadius: 1,
                    offset: const Offset(0, 8), 
                  ),
                ],
              ),
            ),
          ),

          // 1. Liquid Glass Lens 
          Positioned.fill(
            child: ClipRRect(
              borderRadius: effectiveBorderRadius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), 
                child: Container(color: color ?? Colors.white.withOpacity(0.02 * opacity)), 
              ),
            ),
          ),

          // 2. Subtle Concave Rim 
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _InnerShadowPainter(
                  radius: radius,
                  borderRadius: effectiveBorderRadius, // Pass effective radius
                  color: Colors.white.withOpacity(0.2 * opacity), 
                  blur: 2, 
                  offset: const Offset(0, 0), 
                  strokeWidth: 1.2, 
                ),
              ),
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

class _InnerShadowPainter extends CustomPainter {
  final double radius;
  final BorderRadius borderRadius; // Changed to required effective BorderRadius
  final double strokeWidth;
  final Color color;
  final double blur;
  final Offset offset;

  _InnerShadowPainter({
    required this.radius,
    required this.borderRadius,
    this.strokeWidth = 2,
    this.color = const Color(0xB3FFFFFF),
    this.blur = 1,
    this.offset = const Offset(2, 2),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Use toRRect for correct shape processing
    final rrect = borderRadius.toRRect(rect);

    canvas.save();
    canvas.clipRRect(rrect);
    
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 2 
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);

    canvas.drawRRect(rrect.shift(offset), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
