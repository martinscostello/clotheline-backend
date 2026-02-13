import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../models/store_product.dart';

enum SalesBannerMode { badge, flat }

class SalesBanner extends StatelessWidget {
  final SalesBannerConfig config;
  final SalesBannerMode mode;

  const SalesBanner({
    super.key,
    required this.config,
    this.mode = SalesBannerMode.badge,
  });

  @override
  Widget build(BuildContext context) {
    if (!config.isEnabled) return const SizedBox.shrink();

    final Color primaryColor = _parseColor(config.primaryColor);
    final Color secondaryColor = _parseColor(config.secondaryColor);
    final Color accentColor = _parseColor(config.accentColor);

    if (mode == SalesBannerMode.flat) {
      return _buildFlatDesign(primaryColor, secondaryColor, accentColor);
    }

    switch (config.style) {
      case 1: return _buildStyle1(primaryColor, secondaryColor, accentColor);
      case 2: return _buildStyle2(primaryColor, secondaryColor, accentColor);
      case 3: return _buildStyle3(primaryColor, secondaryColor, accentColor);
      case 4: return _buildStyle4(primaryColor, secondaryColor, accentColor);
      case 5: return _buildStyle5(primaryColor, secondaryColor, accentColor);
      case 6: return _buildStyle6(primaryColor, secondaryColor, accentColor);
      default: return _buildStyle1(primaryColor, secondaryColor, accentColor);
    }
  }

  Color _parseColor(String hex) {
    try {
      hex = hex.replaceAll('#', '');
      if (hex.length == 6) hex = "FF$hex";
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return Colors.red;
    }
  }

  // --- FLAT DESIGN (Detail Page Base) ---
  Widget _buildFlatDesign(Color primary, Color secondary, Color accent) {
    return SizedBox(
      width: double.infinity,
      height: 32, // More compact fixed height
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: CustomPaint(
              painter: AdaptiveFlatSectionPainter(color: primary, isLeft: true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 0),
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    config.primaryText,
                    style: TextStyle(color: accent, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: CustomPaint(
              painter: AdaptiveFlatSectionPainter(color: secondary, isLeft: false),
              child: Container(
                padding: const EdgeInsets.fromLTRB(25, 0, 12, 0),
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    config.secondaryText,
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
                    textAlign: TextAlign.right,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- BADGE STYLES (Store Page Top Left) ---

  // Style 1: Folded Folded Tab (Screenshot 1 top left)
  Widget _buildStyle1(Color primary, Color secondary, Color accent) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(45, 6, 12, 6),
          decoration: BoxDecoration(
            color: primary,
            borderRadius: const BorderRadius.only(topRight: Radius.circular(4), bottomRight: Radius.circular(4)),
          ),
          child: Text(
            config.primaryText,
            style: TextStyle(color: secondary, fontWeight: FontWeight.bold, fontSize: 10),
          ),
        ),
        Positioned(
          left: -5, top: -5,
          child: ClipPath(
            clipper: FoldedTabClipper(),
            child: Container(
              width: 45, height: 45,
              color: accent,
              padding: const EdgeInsets.all(4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(config.secondaryText, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                  Text(config.discountText.replaceAll(' OFF', ''), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
                  const Text("OFF", style: TextStyle(color: Colors.white, fontSize: 6, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Style 2: Modern Circle (Screenshot 1 top right variant)
  Widget _buildStyle2(Color primary, Color secondary, Color accent) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 30, 6),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            config.primaryText,
            style: TextStyle(color: secondary, fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ),
        Positioned(
          right: -15, top: -5,
          child: Container(
            width: 45, height: 45,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 Text(config.secondaryText, style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)),
                 Text(config.discountText.split(' ').first, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
                 const Text("OFF", style: TextStyle(color: Colors.white, fontSize: 6, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Style 3: Starburst Seal (Screenshot 1 bottom left)
  Widget _buildStyle3(Color primary, Color secondary, Color accent) {
    return SizedBox(
       width: 60, height: 60,
       child: CustomPaint(
         painter: StarburstPainter(color: primary),
         child: Center(
           child: Column(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               Text(config.primaryText.split(' ').first, style: TextStyle(color: secondary, fontSize: 9, fontWeight: FontWeight.w900)),
               Text(config.primaryText.split(' ').last, style: TextStyle(color: secondary, fontSize: 9, fontWeight: FontWeight.w900)),
               Container(height: 1, width: 25, color: Colors.white30, margin: const EdgeInsets.symmetric(vertical: 2)),
               Text(config.discountText, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
             ],
           ),
         ),
       ),
    );
  }

  // Style 4: Angled Gradient (Screenshot 1 bottom right variant)
  Widget _buildStyle4(Color primary, Color secondary, Color accent) {
    return SizedBox(
      height: 34,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
           ClipPath(
              clipper: TrapezoidClipper(),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 6, 25, 6),
                color: primary,
                child: Text(config.primaryText, style: TextStyle(color: secondary, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
           ),
           Positioned(
             right: -10, top: -5,
             child: Container(
               width: 38, height: 38,
               decoration: BoxDecoration(
                 gradient: LinearGradient(colors: [accent, accent.withValues(alpha: 0.8)]),
                 shape: BoxShape.circle,
                 border: Border.all(color: Colors.white, width: 1),
               ),
               child: Center(
                 child: Text(config.discountText.split(' ').first, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
               ),
             ),
           )
        ],
      ),
    );
  }

  // Style 5: Glass Neon Pill
  Widget _buildStyle5(Color primary, Color secondary, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primary, width: 1.5),
        boxShadow: [
          BoxShadow(color: primary.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 1)
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt, color: secondary, size: 14),
          const SizedBox(width: 4),
          Text(config.primaryText, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Text(config.discountText, style: TextStyle(color: secondary, fontSize: 11, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  // Style 6: Double Ribbon
  Widget _buildStyle6(Color primary, Color secondary, Color accent) {
    return SizedBox(
      height: 50, width: 80,
      child: Stack(
        children: [
          Positioned(
            top: 5, left: 0, right: 0,
            child: Container(
              height: 25,
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              child: Text(config.primaryText, style: TextStyle(color: secondary, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ),
          Positioned(
            bottom: 5, left: 10, right: 10,
            child: Container(
              height: 20,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]
              ),
              alignment: Alignment.center,
              child: Text(config.discountText, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}

// --- CLIPPERS ---

class SlantClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(size.width * 0.9, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class FoldedTabClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height * 0.8);
    path.lineTo(size.width * 0.5, size.height);
    path.lineTo(0, size.height * 0.8);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class TrapezoidClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(size.width, 0);
    path.lineTo(size.width * 0.85, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class StarburstPainter extends CustomPainter {
  final Color color;
  StarburstPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color;
    const int spikes = 16;
    final double outerRadius = size.width / 2;
    final double innerRadius = outerRadius * 0.85;
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;

    Path path = Path();
    for (int i = 0; i < spikes * 2; i++) {
        double radius = (i % 2 == 0) ? outerRadius : innerRadius;
        double angle = (i * math.pi) / spikes;
        double x = centerX + radius * math.cos(angle);
        double y = centerY + radius * math.sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
    }
    path.close();
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class AdaptiveFlatSectionPainter extends CustomPainter {
  final Color color;
  final bool isLeft;

  AdaptiveFlatSectionPainter({required this.color, required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();

    if (isLeft) {
      path.lineTo(size.width, 0);
      path.lineTo(size.width - 20, size.height);
      path.lineTo(0, size.height);
    } else {
      path.moveTo(20, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    }
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(AdaptiveFlatSectionPainter oldDelegate) => oldDelegate.color != color || oldDelegate.isLeft != isLeft;
}
