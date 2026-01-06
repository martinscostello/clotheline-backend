import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import 'dashboard/admin_dashboard_screen.dart';
import 'orders/admin_orders_screen.dart';
import 'cms/admin_cms_screen.dart';
import 'users/admin_users_screen.dart';
import 'settings/admin_settings_screen.dart';
import 'package:laundry_app/widgets/glass/LaundryGlassBackground.dart';

class AdminMainLayout extends StatefulWidget {
  const AdminMainLayout({super.key});

  @override
  State<AdminMainLayout> createState() => _AdminMainLayoutState();
}

class _AdminMainLayoutState extends State<AdminMainLayout> {
  int _currentIndex = 0;
  
  // We will recompute these on every build based on Auth State
  List<Widget> _currentScreens = [];
  List<Map<String, dynamic>> _currentNavItems = [];

  @override
  void initState() {
    super.initState();
    // Trigger an auto-refresh if needed, though Consumer handles updates
    WidgetsBinding.instance.addPostFrameCallback((_) async {
       Provider.of<AuthService>(context, listen: false).tryAutoLogin();
    });
  }

  void _calculateTabs(AuthService authService) {
    List<Widget> screens = [];
    List<Map<String, dynamic>> navItems = [];
    
    final user = authService.currentUser;
    final permissions = user != null ? (user['permissions'] ?? {}) : {};
    final isMaster = user != null && user['isMasterAdmin'] == true;

    // 1. Dashboard (Always)
    screens.add(const AdminDashboardScreen());
    navItems.add({'icon': Icons.dashboard_outlined, 'label': "Dash"});

    // 2. Orders
    if (isMaster || permissions['manageOrders'] == true) {
      screens.add(const AdminOrdersScreen());
      navItems.add({'icon': Icons.list_alt, 'label': "Orders"});
    }

    // 3. CMS
    if (isMaster || permissions['manageCMS'] == true || permissions['manageServices'] == true || permissions['manageProducts'] == true) {
      screens.add(const AdminCMSScreen());
      navItems.add({'icon': Icons.edit_note, 'label': "CMS"});
    }

    // 4. Users
    if (isMaster || permissions['manageUsers'] == true) {
      screens.add(const AdminUsersScreen());
      navItems.add({'icon': Icons.people_outline, 'label': "Users"});
    }

    // 5. Settings (Always)
    screens.add(const AdminSettingsScreen());
    navItems.add({'icon': Icons.settings_outlined, 'label': "Settings"});
    
    _currentScreens = screens;
    _currentNavItems = navItems;
    
    // Safety Correction if permissions change while on a tab that disappears
    if(_currentIndex >= _currentScreens.length) {
      _currentIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to Auth Changes
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        _calculateTabs(authService);
        
        // Show loading if auth is absolutely initializing? 
        // Or just show Dash/Settings (default) until permissions load.
        // We chose to show default tabs immediately to prevent "Infinite Spinner".

        return Scaffold(
          extendBody: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: LaundryGlassBackground(
            child: Stack(
              children: [
                Positioned.fill(child: _currentScreens[_currentIndex]),
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: _buildGlassNavBar(),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildGlassNavBar() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 85,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5), 
            border: Border(top: BorderSide(color: AppTheme.secondaryColor.withValues(alpha: 0.5), width: 1.5)), 
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
               BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 5),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_currentNavItems.length, (index) {
              return _buildNavItem(
                _currentNavItems[index]['icon'], 
                _currentNavItems[index]['label'], 
                index
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected ? AppTheme.secondaryColor : Colors.white38, 
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? AppTheme.secondaryColor : Colors.white38,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
