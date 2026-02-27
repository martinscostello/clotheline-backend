import 'package:flutter/material.dart';

class AddToCartAnimation {
  static void run(BuildContext context, GlobalKey startKey, GlobalKey endKey, VoidCallback onComplete) {
    final overlay = Overlay.of(context);
    
    // Get positions
    final RenderBox? startBox = startKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? endBox = endKey.currentContext?.findRenderObject() as RenderBox?;
    
    if (startBox == null || endBox == null) return;

    final startPos = startBox.localToGlobal(Offset.zero) + Offset(startBox.size.width / 2, startBox.size.height / 2);
    final endPos = endBox.localToGlobal(Offset.zero) + Offset(endBox.size.width / 2, endBox.size.height / 2);

    late OverlayEntry entry;
    
    entry = OverlayEntry(
      builder: (context) {
        return TweenAnimationBuilder(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
          builder: (context, value, child) {
            // Bezier-like curve
            // Simple linear interpolation for X, Parabolic for Y (arc)
            final x = startPos.dx + (endPos.dx - startPos.dx) * value;
            final y = startPos.dy + (endPos.dy - startPos.dy) * value - (100 * (1 - (value - 0.5).abs() * 2)); // Arc height 100

            return Positioned(
              left: x,
              top: y,
              child: Opacity(
                opacity: 1.0 - value, // Fade out slightly at end
                child: Transform.scale(
                  scale: 1.0 - (value * 0.5), // Shrink slightly
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF5722),
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]
                    ),
                  ),
                ),
              ),
            );
          },
          onEnd: () {
            entry.remove();
            onComplete();
          },
        );
      },
    );

    overlay.insert(entry);
  }
}
