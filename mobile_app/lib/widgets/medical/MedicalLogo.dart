import 'package:flutter/material.dart';

class MedicalLogo extends StatelessWidget {
  final double size;

  const MedicalLogo({super.key, this.size = 100});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Blue Medical Cross (Outlined/Styled)
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.transparent,
            ),
            child: CustomPaint(
              painter: _CrossPainter(),
            ),
          ),
          // Red/Orange Leaf Overlay
          Positioned(
            child: Icon(
              Icons.eco, // Placeholder for the leaf shape, or we draw it
              size: size * 0.5,
              color: const Color(0xFFFF6B6B),
            ),
          ),
        ],
      ),
    );
  }
}

class _CrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4A80F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.15
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    
    // Draw Cross
    final path = Path();
    // Vertical bar
    path.moveTo(w * 0.5, h * 0.1);
    path.lineTo(w * 0.5, h * 0.9);
    // Horizontal bar
    path.moveTo(w * 0.1, h * 0.5);
    path.lineTo(w * 0.9, h * 0.5);

    // Actually, reference is a rounded outline cross. 
    // Let's approximate the "Plus" shape.
    
    // canvas.drawPath(path, paint); // Simple line cross
    
    // Better: Draw the outline shape
    final outlinePaint = Paint()
      ..color = const Color(0xFF4A80F0) 
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;

    final p = Path();
    // Top
    p.moveTo(w * 0.35, h * 0.35);
    p.lineTo(w * 0.35, h * 0.15);
    p.quadraticBezierTo(w * 0.35, h * 0.05, w * 0.5, h * 0.05);
    p.quadraticBezierTo(w * 0.65, h * 0.05, w * 0.65, h * 0.15);
    p.lineTo(w * 0.65, h * 0.35);
    // Right
    p.lineTo(w * 0.85, h * 0.35);
    p.quadraticBezierTo(w * 0.95, h * 0.35, w * 0.95, h * 0.5);
    p.quadraticBezierTo(w * 0.95, h * 0.65, w * 0.85, h * 0.65);
    p.lineTo(w * 0.65, h * 0.65);
    // Bottom
    p.lineTo(w * 0.65, h * 0.85);
    p.quadraticBezierTo(w * 0.65, h * 0.95, w * 0.5, h * 0.95);
    p.quadraticBezierTo(w * 0.35, h * 0.95, w * 0.35, h * 0.85);
    p.lineTo(w * 0.35, h * 0.65);
    // Left
    p.lineTo(w * 0.15, h * 0.65);
    p.quadraticBezierTo(w * 0.05, h * 0.65, w * 0.05, h * 0.5);
    p.quadraticBezierTo(w * 0.05, h * 0.35, w * 0.15, h * 0.35);
    p.close();

    canvas.drawPath(p, outlinePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
