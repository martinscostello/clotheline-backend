import 'package:flutter/material.dart';
import 'package:liquid_glass_ui/liquid_glass_ui.dart';

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
    this.blur = 10.0, 
    this.opacity = 0.1, 
    this.borderRadius = 20.0, 
    this.padding,
    this.border,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    // [FIX] Replaced custom implementation with LiquidGlassContainer
    // This solves the pixelation/banding on tablets by using a proven shader/rendering stack.
    return SizedBox(
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          border: border ?? Border.all(color: Colors.white10, width: 0.5),
        ),
        child: LiquidGlassContainer(
          padding: padding ?? const EdgeInsets.all(20),
          blur: blur,
          opacity: opacity,
          borderRadius: BorderRadius.circular(borderRadius),
          color: color, // Optional override
          child: child, // Removed TextShadows as they might look blurry on tablet
        ),
      ),
    );
  }
}
