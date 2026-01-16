import 'package:flutter/material.dart';

class CrystalNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<CrystalNavItem> items;

  const CrystalNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // The "Glass" Color Base - Refined Transparency
    // Dark Mode: Deep Black with medium transparency
    // Light Mode: Clear White with medium transparency
    // Body Gradient Colors
    final bodyStart = isDark ? const Color(0xFF202020).withValues(alpha: 0.85) : const Color(0xFFFFFFFF).withValues(alpha: 0.90);
    final bodyEnd = isDark ? const Color(0xFF101010).withValues(alpha: 0.65) : const Color(0xFFFFFFFF).withValues(alpha: 0.75);

    // Rim Light Colors (The fake refraction)
    final rimTop = isDark ? Colors.white.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.60);
    final rimBottom = isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.10);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20), // Float it
      child: Container(
        height: 75,
        decoration: BoxDecoration(
          // Body Gradient instead of flat color
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [bodyStart, bodyEnd],
          ),
          borderRadius: BorderRadius.circular(30), // Pill Shape
          boxShadow: [
            // 1. Deep Shadow (Lift)
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.25),
              blurRadius: 30,
              offset: const Offset(0, 15),
              spreadRadius: -5,
            ),
          ],
          border: Border.all(
            // Stronger Border
            color: Colors.white.withValues(alpha: isDark ? 0.25 : 0.60),
            width: 1.5,
          )
        ),
        // INNER SHADOW SIMULATION (The "Thickness")
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Stack(
            children: [
               // Rim Highlight Gradient (Top-Left shine)
               Positioned.fill(
                 child: Container(
                   decoration: BoxDecoration(
                     borderRadius: BorderRadius.circular(30),
                     gradient: LinearGradient(
                       begin: Alignment.topLeft,
                       end: Alignment.bottomRight,
                       colors: [
                         rimTop,
                         Colors.transparent,
                         rimBottom,
                       ],
                       stops: const [0.0, 0.4, 1.0],
                     ),
                   ),
                 ),
               ),
               
               // Content
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                 children: items.asMap().entries.map((entry) {
                   final index = entry.key;
                   final item = entry.value;
                   final isSelected = index == currentIndex;

                   return _buildNavItem(context, item, isSelected, () => onTap(index));
                 }).toList(),
               ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, CrystalNavItem item, bool isSelected, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final activeColor = const Color(0xFF0A84FF); // iOS Blue
    final inactiveColor = isDark ? Colors.white : Colors.black; 

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          height: 65, // Full height pill (75 - 10 margin)
          width: isSelected ? 85 : 55, // Expanded width for selected (was 75/50)
          decoration: isSelected 
            ? BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(32.5), // Rounded Pill
              )
            : const BoxDecoration(color: Colors.transparent),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min, // Hug content
            children: [
              Icon(
                isSelected ? item.selectedIcon : item.unselectedIcon,
                color: isSelected ? activeColor : inactiveColor,
                size: 28, 
              ),
              
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: activeColor,
                      fontSize: 10, 
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    softWrap: false,
                  ),
                ),
                crossFadeState: isSelected ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CrystalNavItem {
  final String label;
  final IconData unselectedIcon;
  final IconData selectedIcon;

  const CrystalNavItem({
    required this.label,
    required this.unselectedIcon,
    required this.selectedIcon,
  });
}
