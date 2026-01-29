import 'package:flutter/material.dart';
import 'package:laundry_app/widgets/glass/LiquidBackground.dart';
import 'package:laundry_app/widgets/glass/GlassContainer.dart';
import 'package:laundry_app/theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../auth/login_screen.dart';
import '../../../services/auth_service.dart';
import '../../../widgets/common/user_avatar.dart';

import 'admin_manage_admins_screen.dart';
import 'admin_delivery_settings_screen.dart';
import 'admin_tax_settings_screen.dart';

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
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
                Center(
                  child: Consumer<AuthService>(
                    builder: (context, auth, _) {
                      final user = auth.currentUser;
                      return Column(
                        children: [
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              UserAvatar(
                                avatarId: user?['avatarId'],
                                name: user?['name'] ?? 'A',
                                radius: 50,
                                isDark: true,
                              ),
                              GestureDetector(
                                onTap: () => _showAvatarPicker(context),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(0.9),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(Icons.edit, size: 16, color: Colors.black),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          Text(
                            user?['name'] ?? 'Admin',
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            user?['email'] ?? '',
                            style: const TextStyle(color: Colors.white54, fontSize: 14),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 40),
                const Text("Organization", style: TextStyle(color: Colors.white54, fontSize: 14)),
                const SizedBox(height: 10),
                GlassContainer(
                  opacity: 0.1,
                  child: Consumer<AuthService>(
                    builder: (context, auth, _) {
                      final isMaster = auth.currentUser != null && auth.currentUser!['isMasterAdmin'] == true;
                      return Column(
                        children: [
                          if (isMaster)
                            _buildSettingTile(Icons.admin_panel_settings, "Manage Administrators", () {
                               Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminManageAdminsScreen()));
                            }),
                          _buildSettingTile(Icons.local_shipping, "Delivery Zones & Fees", () {
                             Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDeliverySettingsScreen()));
                          }),
                          _buildSettingTile(Icons.percent, "Tax Settings (VAT)", () {
                             Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminTaxSettingsScreen()));
                          }),
                        ],
                      );
                    }
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
                    onPressed: () async {
                       await Provider.of<AuthService>(context, listen: false).logout();
                       if (context.mounted) {
                         Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                            (route) => false
                         );
                       }
                    }, 
                    icon: const Icon(Icons.logout),
                    label: const Text("Admin Logout"),
                  ),
                )
              ],
            ),
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

  void _showAvatarPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Consumer<AuthService>(
        builder: (context, auth, _) {
          return Column(
            children: [
              const SizedBox(height: 20),
              const Text("Select Exclusive Admin Avatar", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, 
                    mainAxisSpacing: 15, 
                    crossAxisSpacing: 15
                  ),
                  itemCount: 10,
                  itemBuilder: (context, index) {
                    final avatarId = 'a_${index + 1}';
                    final isSelected = auth.currentUser?['avatarId'] == avatarId;
                    return GestureDetector(
                      onTap: () {
                        auth.updateAvatar(avatarId);
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: isSelected ? AppTheme.primaryColor : Colors.transparent, width: 3),
                        ),
                        child: UserAvatar(avatarId: avatarId, name: "Admin", radius: 40, isDark: true),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
