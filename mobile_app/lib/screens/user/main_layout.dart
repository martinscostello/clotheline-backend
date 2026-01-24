import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass/LaundryGlassBackground.dart';
import '../../widgets/navigation/CrystalNavBar.dart'; // Fixed import
// Fixed relative path
import 'dashboard_screen.dart';
import 'products/products_screen.dart';
import 'orders/orders_screen.dart';
import 'settings/settings_screen.dart';
import '../../services/push_notification_service.dart';

class MainLayout extends StatefulWidget {
  final int initialIndex;
  const MainLayout({super.key, this.initialIndex = 0});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  final ValueNotifier<int> _tabNotifier = ValueNotifier(0);

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _loadPersistedTab();
    _screens = [
      DashboardScreen(
        onSwitchToStore: () => _updateIndex(1),
        tabNotifier: _tabNotifier, // Pass Notifier
      ),
      const ProductsScreen(),
      const OrdersScreen(),
      const SettingsScreen(),
    ];
    
    // [DEAD-STATE] Handle Notification Deep Links
    PushNotificationService.setupInteractedMessage(context);
    
    // [BATTERY] Request Optimization Ignore (Android)
    PushNotificationService.checkBatteryOptimization(context);
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
     _tabNotifier.value = index; // Notify listeners
     final prefs = await SharedPreferences.getInstance();
     prefs.setInt('last_tab_index', index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false, // Prevents keyboard from pushing nav bar
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
      height: 75, // Original
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20), // Original floating
      backgroundColor: Theme.of(context).brightness == Brightness.dark 
          ? Colors.black.withOpacity(0.8) 
          : Colors.white.withOpacity(0.9),
      indicatorColor: AppTheme.primaryColor,
      unselectedItemColor: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black45,
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
