import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass/LaundryGlassBackground.dart';
import '../../widgets/navigation/CrystalNavBar.dart'; // Fixed import
import '../common/branch_selection_screen.dart'; // Fixed relative path
import 'dashboard_screen.dart';
import 'products/products_screen.dart';
import 'orders/orders_screen.dart';
import 'settings/settings_screen.dart';

class MainLayout extends StatefulWidget {
  final int initialIndex;
  const MainLayout({super.key, this.initialIndex = 0});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _loadPersistedTab();
    _screens = [
      DashboardScreen(
        onSwitchToStore: () => _updateIndex(1),
      ),
      const ProductsScreen(),
      const OrdersScreen(),
      const SettingsScreen(),
    ];
  }

  Future<void> _loadPersistedTab() async {
    if (widget.initialIndex != 0) {
       _currentIndex = widget.initialIndex;
    } else {
       // Only load persistence if no specific override provided
       final prefs = await SharedPreferences.getInstance();
       final savedIndex = prefs.getInt('last_tab_index') ?? 0;
       if (savedIndex >= 0 && savedIndex < _screens.length) {
         setState(() => _currentIndex = savedIndex);
       }
    }
  }

  Future<void> _updateIndex(int index) async {
     setState(() => _currentIndex = index);
     final prefs = await SharedPreferences.getInstance();
     prefs.setInt('last_tab_index', index);
  }

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
    return CrystalNavBar(
      currentIndex: _currentIndex,
      onTap: (index) => _updateIndex(index),
      items: const [
        CrystalNavItem(
          label: "Home", 
          unselectedIcon: CupertinoIcons.house, 
          selectedIcon: CupertinoIcons.house_fill
        ),
        CrystalNavItem(
          label: "Store", 
          unselectedIcon: CupertinoIcons.bag, 
          selectedIcon: CupertinoIcons.bag_fill
        ),
        CrystalNavItem(
          label: "Orders", 
          unselectedIcon: CupertinoIcons.ticket, 
          selectedIcon: CupertinoIcons.ticket_fill
        ),
        CrystalNavItem(
          label: "Settings", 
          unselectedIcon: CupertinoIcons.person_crop_circle, 
          selectedIcon: CupertinoIcons.person_crop_circle_fill
        ),
      ],
    );
  }
}
