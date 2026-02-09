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
import 'settings/admin_settings_screen.dart'; // [FIXED Path]
import '../../widgets/navigation/NavScaffold.dart';
import '../../widgets/navigation/PremiumNavBar.dart';
import '../../widgets/glass/LaundryGlassBackground.dart'; // [FIXED Path]

class AdminMainLayout extends StatefulWidget {
  final int initialIndex;
  final int initialOrderTabIndex;
  const AdminMainLayout({super.key, this.initialIndex = 0, this.initialOrderTabIndex = 0});

  @override
  State<AdminMainLayout> createState() => _AdminMainLayoutState();
}

class _AdminMainLayoutState extends State<AdminMainLayout> {
  int _currentIndex = 0;
  List<Widget> _currentScreens = []; // [FIXED: Added missing field]
  List<Map<String, dynamic>> _currentNavItems = []; // [FIXED: Added missing field]

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    // Trigger an auto-refresh if needed, though Consumer handles updates
    WidgetsBinding.instance.addPostFrameCallback((_) async {
       Provider.of<AuthService>(context, listen: false).tryAutoLogin();
    });
  }

  void _calculateTabs() {
    // All screens are now visible to all admins
    _currentScreens = [
      const AdminDashboardScreen(),
      AdminOrdersScreen(initialTabIndex: widget.initialOrderTabIndex),
      const AdminCMSScreen(),
      const AdminUsersScreen(),
      const AdminChatScreen(),
      const AdminSettingsScreen(),
    ];

    _currentNavItems = [
      {'icon': Icons.dashboard_outlined, 'label': "Dash", 'permission': null},
      {'icon': Icons.list_alt, 'label': "Orders", 'permission': 'manageOrders'},
      {'icon': Icons.edit_note, 'label': "CMS", 'permission': null}, // Always open, check inner modules
      {'icon': Icons.people_outline, 'label': "Users", 'permission': 'manageUsers'},
      {'icon': Icons.chat_outlined, 'label': "Chat", 'permission': 'manageChat'},
      {'icon': Icons.settings_outlined, 'label': "Settings", 'permission': ['manageSettings', 'manageAdmins']},
    ];
  }

  bool _checkPermission(int index) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return false;
    if (user['isMasterAdmin'] == true) return true;

    final permissionRequirement = _currentNavItems[index]['permission'];
    if (permissionRequirement == null) return true;

    final permissions = user['permissions'] ?? {};
    bool hasAccess = false;

    if (permissionRequirement is String) {
      hasAccess = permissions[permissionRequirement] == true;
    } else if (permissionRequirement is List) {
      hasAccess = permissionRequirement.any((p) => permissions[p] == true);
    }

    if (!hasAccess) {
      _showRestrictionPopup(_currentNavItems[index]['label']);
      auth.logPermissionViolation(_currentNavItems[index]['label']);
    }

    return hasAccess;
  }

  void _showRestrictionPopup(String feature) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.redAccent, width: 2)
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 10),
            Text("Access Denied", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          "You do not have permission to access this page, an auto request has been sent to the master admin of your attempt to access this page",
          style: TextStyle(color: Colors.white70)
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK", style: TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold))
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen to Auth Changes
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        _calculateTabs();
        
        // Show loading if auth is absolutely initializing? 
        // Or just show Dash/Settings (default) until permissions load.
        // We chose to show default tabs immediately to prevent "Infinite Spinner".
        
        final bottomPadding = MediaQuery.of(context).padding.bottom;
        final bool isButtonNav = bottomPadding > 45;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
            systemNavigationBarColor: isButtonNav ? Colors.black : Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.light,
            systemNavigationBarDividerColor: isButtonNav ? Colors.black : Colors.transparent,
          ),
          child: Theme(
            data: AppTheme.darkTheme,
            child: NavScaffold(
              currentIndex: _currentIndex,
              onTabTap: (index) {
                if (_checkPermission(index)) {
                  setState(() => _currentIndex = index);
                }
              },
              navMargin: EdgeInsets.zero,
              navBorderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
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
          ),
        );
      }
    );
  }
}
