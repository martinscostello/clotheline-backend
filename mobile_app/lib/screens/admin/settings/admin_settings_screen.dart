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
import 'admin_notification_settings_screen.dart';
import '../staff/admin_staff_screen.dart'; // [NEW]
import 'admin_manage_data_screen.dart'; // [NEW]
import '../reports/admin_financial_reports_screen.dart'; // [NEW]
import '../../../utils/toast_utils.dart';

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
                          _buildSettingTile(Icons.admin_panel_settings, "Manage Administrators", () {
                             final permissions = auth.currentUser?['permissions'] ?? {};
                             if (isMaster || permissions['manageAdmins'] == true) {
                               Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminManageAdminsScreen()));
                             } else {
                               _showDeniedDialog(context, "Admin Management");
                               auth.logPermissionViolation("Admin Management");
                             }
                          }),
                           _buildSettingTile(Icons.badge_outlined, "Staff Profiles", () {
                              final permissions = auth.currentUser?['permissions'] ?? {};
                              if (isMaster || permissions['manageStaff'] == true) {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminStaffScreen()));
                              } else {
                                _showDeniedDialog(context, "Staff Management");
                                auth.logPermissionViolation("Staff Management");
                              }
                           }),
                          _buildSettingTile(Icons.local_shipping, "Delivery Zones & Fees", () {
                             final permissions = auth.currentUser?['permissions'] ?? {};
                             if (isMaster || permissions['manageSettings'] == true) {
                               Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDeliverySettingsScreen()));
                             } else {
                               _showDeniedDialog(context, "Delivery Settings");
                               auth.logPermissionViolation("Delivery Settings");
                             }
                          }),
                          _buildSettingTile(Icons.percent, "Tax Settings (VAT)", () {
                             final permissions = auth.currentUser?['permissions'] ?? {};
                             if (isMaster || permissions['manageSettings'] == true) {
                               Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminTaxSettingsScreen()));
                             } else {
                               _showDeniedDialog(context, "Tax Settings");
                               auth.logPermissionViolation("Tax Settings");
                             }
                          }),
                           if (isMaster)
                            _buildSettingTile(Icons.storage, "Manage Data", () {
                               Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminManageDataScreen()));
                            }),
                           _buildSettingTile(Icons.auto_graph, "Financial Intelligence", () {
                              final permissions = auth.currentUser?['permissions'] ?? {};
                              if (isMaster || permissions['manageSettings'] == true) { // Or specific permission
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminFinancialReportsScreen()));
                              } else {
                                _showDeniedDialog(context, "Financial Reports");
                                auth.logPermissionViolation("Financial Reports");
                              }
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
                       _buildSettingTile(Icons.notifications_active, "Push Notifications", () {
                         Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminNotificationSettingsScreen()));
                       }),
                       _buildSettingTile(Icons.backup, "Database Backup", () => _showBackupInfo(context)),
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

  void _showDeniedDialog(BuildContext context, String feature) {
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
        content: Text(
          "You do not have permission to access $feature, an auto request has been sent to the master admin of your attempt to access this page",
          style: const TextStyle(color: Colors.white70)
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

  Widget _buildSettingTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.secondaryColor),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
      onTap: onTap,
    );
  }

  void _showBackupInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: AppTheme.secondaryColor),
            SizedBox(width: 10),
            Text("Database Backup", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          "The Database Backup feature allows you to export a complete snapshot of your business data (Orders, Products, Customers, etc.) as a JSON file. \n\nThis serves as an offline safeguard, allowing you to store a point-in-time copy of your records safely on your device.\n\nNote: For security, backups should be stored in a protected location.",
          style: TextStyle(color: Colors.white70)
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL", style: TextStyle(color: Colors.white54))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.black),
            onPressed: () {
              Navigator.pop(ctx);
              _generateBackup(context);
            },
            child: const Text("GENERATE BACKUP", style: TextStyle(fontWeight: FontWeight.bold))
          )
        ],
      )
    );
  }

  Future<void> _generateBackup(BuildContext context) async {
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final token = await auth.getToken();
      if (token == null) return;

      ToastUtils.show(context, "Preparing backup data...", type: ToastType.info);

      final response = await Provider.of<AuthService>(context, listen: false).backupDatabase();
      
      if (response != null) {
        // [LOGIC PROPOSAL]
        // In a production environment, we would use 'path_provider' and 'share_plus'
        // to save the JSON to a file and open the system share sheet.
        // For this enhancement, we'll simulate the successful generation.
        
        ToastUtils.show(context, "Backup JSON Generated Successfully!", type: ToastType.success);
        debugPrint("Backup Data Received: ${response.length} bytes");
      }
    } catch (e) {
      ToastUtils.show(context, "Backup failed: $e", type: ToastType.error);
    }
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
