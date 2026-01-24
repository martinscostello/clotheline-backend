import 'package:flutter/material.dart';
import 'package:liquid_glass_ui/liquid_glass_ui.dart';

class UnifiedGlassHeader extends StatelessWidget {
  final Widget title;
  final List<Widget>? actions;
  final bool isDark;
  final double height;
  final VoidCallback? onBack;
  final Widget? bottom; // Added bottom widget support

  const UnifiedGlassHeader({
    super.key,
    required this.title,
    required this.isDark,
    this.actions,
    this.height = 80,
    this.onBack,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    // Top Padding for Safe Area
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity, // Ensure full width
      padding: EdgeInsets.only(
        top: topPadding,
        left: 20,
        right: 20,
        bottom: 10,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            isDark ? const Color(0xFF101010) : Colors.white, // Match LaundryGlassBackground
            isDark ? const Color(0xFF101010).withOpacity(0.0) : Colors.white.withOpacity(0.0),
          ],
          stops: const [0.0, 1.0],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: height - 10, // Base height
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left: Back Button or Title
                Expanded(
                  child: Row(
                    children: [
                      if (onBack != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 15),
                          child: GestureDetector(
                            onTap: onBack,
                            child: Container(
                              height: 50, // Uniform 50px height
                              width: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                              ),
                              child: Icon(Icons.arrow_back_ios_new, size: 20, color: isDark ? Colors.white : Colors.black),
                            ),
                          ),
                        ),
                      Expanded(child: title),
                    ],
                  ),
                ),
                
                // Right: Actions
                if (actions != null)
                  Container(
                    height: 52, // Fixed height for glass actions
                    alignment: Alignment.center,
                    child: LiquidGlassContainer(
                      radius: actions!.length == 1 ? 26 : 30, // Circle if single, Capsule if multiple
                      padding: EdgeInsets.symmetric(horizontal: actions!.length == 1 ? 0 : 16, vertical: 0),
                      child: SizedBox(
                        width: actions!.length == 1 ? 52 : null, // Fixed width for circle
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: actions!,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (bottom != null)
             Padding(
               padding: const EdgeInsets.only(top: 8),
               child: bottom!,
             )
        ],
      ),
    );
  }
}
