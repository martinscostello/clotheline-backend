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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    
    return SizedBox(
      width: width,
      height: height,
      child: Container(
        padding: padding ?? const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color ?? backgroundColor,
          borderRadius: BorderRadius.circular(borderRadius),
          border: border ?? Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black12, 
            width: 0.5
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
