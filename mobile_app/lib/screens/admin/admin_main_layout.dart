import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import 'dashboard/admin_dashboard_screen.dart';
import 'orders/admin_orders_screen.dart';
import 'cms/admin_cms_screen.dart';
import 'users/admin_users_screen.dart';
import 'chat/admin_chat_screen.dart';
import 'settings/admin_settings_screen.dart';
import 'package:laundry_app/widgets/glass/LaundryGlassBackground.dart';
import '../../widgets/navigation/NavScaffold.dart';
import '../../widgets/navigation/PremiumNavBar.dart';

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

    // 5. Chat (Always for Admins)
    screens.add(const AdminChatScreen());
    navItems.add({'icon': Icons.chat_outlined, 'label': "Chat"});

    // 6. Settings (Always)
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

        final isDark = authService.currentUser != null; // Admin is usually dark theme fixed, but let's be robust
        
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
        ));

        return Theme(
          data: AppTheme.darkTheme,
          child: NavScaffold(
            currentIndex: _currentIndex,
            onTabTap: (index) => setState(() => _currentIndex = index),
            navItems: _currentNavItems.map((item) => PremiumNavItem(
              label: item['label'],
              icon: item['icon'],
            )).toList(),
            body: LaundryGlassBackground(
              child: IndexedStack(
                index: _currentIndex,
                children: _currentScreens,
              ),
            ),
          ),
        );
      }
    );
  }
}
