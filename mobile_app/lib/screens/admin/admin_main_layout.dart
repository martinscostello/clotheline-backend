import 'dart:ui';
import 'package:flutter/material.dart';
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

  final List<Widget> _screens = [
    const AdminDashboardScreen(),
    const AdminOrdersScreen(),
    const AdminCMSScreen(),
    const AdminUsersScreen(),
    const AdminSettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: LaundryGlassBackground(
        child: Stack(
          children: [
            Positioned.fill(child: _screens[_currentIndex]),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _buildGlassNavBar(),
            ),
          ],
        ),
      ),
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
            color: Colors.black.withValues(alpha: 0.5), // Slightly darker for Admin
            border: Border(top: BorderSide(color: AppTheme.secondaryColor.withValues(alpha: 0.5), width: 1.5)), // Purple border for Admin
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
               BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 5),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.dashboard_outlined, "Dash", 0),
              _buildNavItem(Icons.list_alt, "Orders", 1),
              _buildNavItem(Icons.edit_note, "CMS", 2),
              _buildNavItem(Icons.people_outline, "Users", 3),
              _buildNavItem(Icons.settings_outlined, "Config", 4),
            ],
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
            color: isSelected ? AppTheme.secondaryColor : Colors.white38, // Purple for Admin
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
