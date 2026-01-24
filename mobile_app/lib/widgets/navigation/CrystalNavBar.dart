import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_ui/liquid_glass_ui.dart';

class CrystalNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<CrystalNavItem> items;
  final double height;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? indicatorColor;
  final Color? unselectedItemColor;

  const CrystalNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.height = 75,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
    this.backgroundColor,
    this.indicatorColor,
    this.unselectedItemColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: padding,
      child: SizedBox(
        height: height,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1), 
              width: 1
            ),
          ),
          child: LiquidGlassContainer(
            opacity: isDark ? 0.2 : 0.1, // Matches Notification Style
            blur: 15,
            borderRadius: BorderRadius.circular(30), // Pill Shape
            child: Stack(
              children: [
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
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, CrystalNavItem item, bool isSelected, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    const activeColor = Color(0xFF0A84FF); // iOS Blue
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
                    style: const TextStyle(
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
