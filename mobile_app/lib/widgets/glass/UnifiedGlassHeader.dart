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

    if (!isDark) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.only(top: topPadding, left: 20, right: 20, bottom: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.95),
              Colors.white.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 1.0],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: height - 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        if (onBack != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 15),
                            child: GestureDetector(
                              onTap: onBack,
                              child: Container(
                                height: 50,
                                width: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withValues(alpha: 0.05),
                                ),
                                child: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black),
                              ),
                            ),
                          ),
                        Expanded(child: title),
                      ],
                    ),
                  ),
                  if (actions != null)
                    Container(
                      height: 52,
                      alignment: Alignment.center,
                      child: LiquidGlassContainer(
                        radius: actions!.length == 1 ? 26 : 30,
                        padding: EdgeInsets.symmetric(horizontal: actions!.length == 1 ? 0 : 16, vertical: 0),
                        child: SizedBox(
                          width: actions!.length == 1 ? 52 : null,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: actions!,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (bottom != null)
              Padding(padding: const EdgeInsets.only(top: 8), child: bottom!),
          ],
        ),
      );
    }

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
            const Color(0xFF0F2027).withValues(alpha: 0.8), // Start with some opacity
            const Color(0xFF0F2027).withValues(alpha: 0.0), // Fade to transparent
          ],
          stops: const [0.0, 1.0],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: height - 10), // [FIX] Use minHeight instead of fixed height
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
                                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
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
