import 'dart:ui';
import 'package:flutter/material.dart';

class FigmaGlassCard extends StatelessWidget {
  final Widget child;
  final double blur;
  final double radius;
  final BoxBorder? border; // allow custom border

  const FigmaGlassCard({
    super.key,
    required this.child,
    this.blur = 28.0,
    this.radius = 32.0,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Tune: Lower opacity for "Crystal" look (was 0.2/0.24)
    final fillColor = isDark 
        ? const Color(0xFF0A2846).withValues(alpha: 0.15) 
        : Colors.white.withValues(alpha: 0.08); // Much much clearer
    
    // Spec: Inner Shadow Simulation (Container Overlay)
    // 0 0 12 rgba(255,255,255,0.25)
    final innerShadowColor = Colors.white.withValues(alpha: 0.25);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          // Outer Shadow: 0 16 40 rgba(0,0,0,0.15)
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            offset: const Offset(0, 16),
            blurRadius: 40,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: fillColor,
                  borderRadius: BorderRadius.circular(radius),
                ),
                child: CustomPaint(
                  painter: _GradientBorderPainter(
                    radius: radius,
                    strokeWidth: 1.5,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.6),
                        Colors.cyanAccent.withValues(alpha: 0.1),
                        Colors.white.withValues(alpha: 0.05),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                  child: child,
                ),
              ),
              
              // 2. Specular Highlight (Top-Left Glint)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 150,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
                    gradient: RadialGradient(
                      center: Alignment.topLeft,
                      radius: 1.5,
                      colors: [
                        Colors.white.withValues(alpha: 0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              
              // 3. Inner Shadow Simulation (Container Overlay)
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        innerShadowColor,
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GradientBorderPainter extends CustomPainter {
  final double radius;
  final double strokeWidth;
  final Gradient gradient;

  _GradientBorderPainter({required this.radius, required this.strokeWidth, required this.gradient});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(strokeWidth / 2, strokeWidth / 2, size.width - strokeWidth, size.height - strokeWidth);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = gradient.createShader(rect);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
