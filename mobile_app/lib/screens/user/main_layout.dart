import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/glass/LaundryGlassBackground.dart';
import '../../widgets/navigation/NavScaffold.dart';
import '../../widgets/navigation/PremiumNavBar.dart';
// Fixed relative path
import 'dashboard_screen.dart';
import 'products/products_screen.dart';
import 'orders/orders_screen.dart';
import 'settings/settings_screen.dart';
import '../../services/push_notification_service.dart';

class MainLayout extends StatefulWidget {
  final int initialIndex;
  final int initialOrderTabIndex; // [NEW]
  const MainLayout({super.key, this.initialIndex = 0, this.initialOrderTabIndex = 0});

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
      OrdersScreen(initialIndex: widget.initialOrderTabIndex), // [NEW]
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
  void dispose() {
    _tabNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Set System UI Overlay for edge-to-edge transparency
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ));

    return NavScaffold(
      currentIndex: _currentIndex,
      onTabTap: _updateIndex,
      navItems: const [
        PremiumNavItem(label: "Home", icon: CupertinoIcons.house_fill),
        PremiumNavItem(label: "Store", icon: CupertinoIcons.bag_fill),
        PremiumNavItem(label: "Orders", icon: CupertinoIcons.ticket_fill),
        PremiumNavItem(label: "Settings", icon: CupertinoIcons.person_crop_circle_fill),
      ],
      body: LaundryGlassBackground(
        child: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
      ),
    );
  }
}
