import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:laundry_app/theme/app_theme.dart';
import 'package:laundry_app/widgets/glass/LaundryGlassBackground.dart';
import 'package:laundry_app/widgets/glass/UnifiedGlassHeader.dart';
import 'package:laundry_app/widgets/glass/LaundryGlassCard.dart';
import '../../../services/auth_service.dart';
import 'manage_password_screen.dart';
import '../../../../widgets/dialogs/delete_account_dialog.dart';
import '../../auth/login_screen.dart';

class ManageAccountScreen extends StatelessWidget {
  const ManageAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: LaundryGlassBackground(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(top: 120, left: 20, right: 20, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Account Security",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: secondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LaundryGlassCard(
                    opacity: isDark ? 0.12 : 0.05,
                    child: ListTile(
                      leading: const Icon(Icons.lock_outline, color: AppTheme.primaryColor),
                      title: Text("Change Password", style: TextStyle(color: textColor)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ManagePasswordScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    "Danger Zone",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  LaundryGlassCard(
                    opacity: isDark ? 0.12 : 0.05,
                    child: ListTile(
                      leading: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent),
                      title: const Text("Delete Account", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      subtitle: Text("Permanently remove your account and data", style: TextStyle(color: secondaryTextColor, fontSize: 12)),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => DeleteAccountDialog(
                            onDelete: () async {
                              await context.read<AuthService>().deleteAccount();
                              if (context.mounted) {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                                  (route) => false,
                                );
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      "Deleting your account will result in the loss of all active orders, reward points, and profile information. This action is not reversible.",
                      style: TextStyle(color: secondaryTextColor, fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0, left: 0, right: 0,
              child: UnifiedGlassHeader(
                isDark: isDark,
                title: Text("Manage Account", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
                onBack: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
