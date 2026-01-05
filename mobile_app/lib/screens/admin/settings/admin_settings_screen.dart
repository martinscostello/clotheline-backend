import 'package:flutter/material.dart';
import 'package:laundry_app/widgets/glass/LiquidBackground.dart';
import 'package:laundry_app/widgets/glass/GlassContainer.dart';
import 'package:laundry_app/theme/app_theme.dart';

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
     return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Admin Config", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: LiquidBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 100, bottom: 100, left: 20, right: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Organization", style: TextStyle(color: Colors.white54, fontSize: 14)),
              const SizedBox(height: 10),
              GlassContainer(
                opacity: 0.1,
                child: Column(
                  children: [
                    _buildSettingTile(Icons.admin_panel_settings, "Manage Administrators", () {}),
                    _buildSettingTile(Icons.local_shipping, "Delivery Zones & Fees", () {}),
                    _buildSettingTile(Icons.percent, "Global Discounts", () {}),
                  ],
                ),
              ),

              const SizedBox(height: 30),
              const Text("App System", style: TextStyle(color: Colors.white54, fontSize: 14)),
              const SizedBox(height: 10),
              GlassContainer(
                opacity: 0.1,
                child: Column(
                  children: [
                    _buildSettingTile(Icons.notifications_active, "Push Notifications", () {}),
                    _buildSettingTile(Icons.backup, "Database Backup", () {}),
                  ],
                ),
              ),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.2),
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed: () {
                     // Log out
                     Navigator.of(context).popUntil((route) => route.isFirst);
                  }, 
                  icon: const Icon(Icons.logout),
                  label: const Text("Admin Logout"),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.secondaryColor),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
      onTap: onTap,
    );
  }
}
