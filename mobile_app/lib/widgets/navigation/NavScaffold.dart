import 'package:flutter/material.dart';
import 'PremiumNavBar.dart';

class NavScaffold extends StatelessWidget {
  final Widget body;
  final int currentIndex;
  final List<PremiumNavItem> navItems;
  final Function(int) onTabTap;
  final bool extendBody;
  final EdgeInsetsGeometry? navMargin;
  final BorderRadius? navBorderRadius;

  const NavScaffold({
    super.key,
    required this.body,
    required this.currentIndex,
    required this.navItems,
    required this.onTabTap,
    this.extendBody = true,
    this.navMargin,
    this.navBorderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: extendBody,
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. Content
          Positioned.fill(child: body),

          // 2. Floating Navigation Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: PremiumNavBar(
              currentIndex: currentIndex,
              items: navItems,
              onTap: onTabTap,
              margin: navMargin,
              borderRadius: navBorderRadius,
            ),
          ),
        ],
      ),
    );
  }
}
