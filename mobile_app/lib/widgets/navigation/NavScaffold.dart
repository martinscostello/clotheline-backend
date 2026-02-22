import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'PremiumNavBar.dart';
import 'GlassSidebar.dart';

class NavScaffold extends StatelessWidget {
  final Widget body;
  final int currentIndex;
  final List<PremiumNavItem> navItems;
  final Function(int) onTabTap;
  final bool extendBody;
  final EdgeInsetsGeometry? navMargin;
  final BorderRadius? navBorderRadius;
  final VoidCallback? onLogout;

  const NavScaffold({
    super.key,
    required this.body,
    required this.currentIndex,
    required this.navItems,
    required this.onTabTap,
    this.extendBody = true,
    this.navMargin,
    this.navBorderRadius,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isTablet = (width >= 600) || kIsWeb; // Galaxy Z Fold 6 Threshold (600px+)

    if (isTablet) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Row(
          children: [
            GlassSidebar(
              currentIndex: currentIndex,
              items: navItems,
              onTap: onTabTap,
              onLogout: onLogout,
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

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
