import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass/LaundryGlassBackground.dart';
import 'package:liquid_glass_ui/liquid_glass_ui.dart';
import 'dashboard_screen.dart';
import 'products/products_screen.dart';
import 'orders/orders_screen.dart';
import 'settings/settings_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const ProductsScreen(), // Store
    const OrdersScreen(),   // Order History
    const SettingsScreen(), // Settings
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: LaundryGlassBackground(
        child: Stack(
          children: [
            // 1. Current Screen Content
            Positioned.fill(
              child: IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
            ),

            // 2. Flush Glass Nav Bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildCustomNavBar(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomNavBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // [FIX] Flush Layout: No Margins, Full Width
    // Added SafeArea bottom padding handling manually or via LiquidGlassContainer padding if needed
    // But since it's a fixed height container, we usually want to extend to bottom.
    // Let's make it taller to cover Home Indicator on iOS.
    
    return LiquidGlassContainer(
      // [FIX] Custom shape: Rounded Top Only
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      padding: EdgeInsets.only(
        left: 20, 
        right: 20, 
        top: 10,
        // Add padding for Home Indicator
        bottom: MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom : 10
      ), 
      // Auto-height based on content + padding
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem("Home", Icons.home_filled, 0, isDark),
          _buildNavItem("Store", Icons.shopping_bag_outlined, 1, isDark),
          _buildNavItem("Orders", Icons.receipt_long_outlined, 2, isDark),
          _buildNavItem("Settings", Icons.person_outline, 3, isDark),
        ],
      ),
    );
  }

  Widget _buildNavItem(String label, IconData icon, int index, bool isDark) {
    final isSelected = _currentIndex == index;
    // Dynamic Colors
    final selectedIconColor = isDark ? Colors.white : Colors.black;
    final unselectedIconColor = isDark ? Colors.white60 : Colors.black54;
    final selectedTextColor = isDark ? Colors.white : Colors.black;
    final unselectedTextColor = isDark ? Colors.white70 : Colors.black54;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 70, // Fixed width for touch target
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated Icon Container
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.all(isSelected ? 8 : 0),
              decoration: isSelected 
                  ? BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2), 
                      shape: BoxShape.circle,
                      boxShadow: [
                         BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 1),
                      ]
                    ) 
                  : const BoxDecoration(),
              child: Icon(
                icon, 
                size: 26, 
                color: isSelected ? selectedIconColor : unselectedIconColor,
              ),
            ),
             const SizedBox(height: 4),
             // Label
             AnimatedOpacity(
               duration: const Duration(milliseconds: 200),
               opacity: isSelected ? 1.0 : 0.6,
               child: Text(
                 label,
                 style: TextStyle(
                   color: isSelected ? selectedTextColor : unselectedTextColor,
                   fontSize: 10,
                   fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                 ),
               ),
             ),
          ],
        ),
      ),
    );
  }
}
