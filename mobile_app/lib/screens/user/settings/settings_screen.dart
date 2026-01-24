import 'package:laundry_app/main.dart'; // Access themeNotifier
import 'package:flutter/material.dart';
import 'package:laundry_app/theme/app_theme.dart';
import 'package:laundry_app/screens/auth/login_screen.dart';
import 'package:laundry_app/widgets/glass/GlassContainer.dart';
import 'package:liquid_glass_ui/liquid_glass_ui.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import 'notification_settings_screen.dart';
import 'faqs_screen.dart'; // Added Import
import 'feedback_screen.dart'; // Added Import
import 'manage_password_screen.dart'; // Added Import
import 'about_screen.dart'; // Added Import
import '../chat/chat_screen.dart'; // Added Import
import 'package:laundry_app/widgets/glass/UnifiedGlassHeader.dart';
import 'package:laundry_app/widgets/glass/LaundryGlassBackground.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
              padding: const EdgeInsets.only(top: 130, bottom: 140, left: 20, right: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Profile Header
                  Consumer<AuthService>(
                    builder: (context, auth, _) {
                      final user = auth.currentUser;
                      // [FIX] No more hardcoded guest fallback. 
                      // If data is missing despite being logged in, it means persistence failed or is loading.
                      final name = user?['name'] ?? '';
                      final email = user?['email'] ?? '';
                      
                      // Auto-Refresh if logged in but nameless (Ghost Fix)
                      if (user != null && (name.isEmpty || email.isEmpty)) {
                         WidgetsBinding.instance.addPostFrameCallback((_) {
                           // Trigger background refresh if we haven't lately
                           auth.validateSession(); 
                         });
                      }
                      
                      return Column(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'U',
                              style: TextStyle(fontSize: 30, color: isDark ? Colors.white : Colors.grey, fontWeight: FontWeight.bold)
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(name, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(email, style: TextStyle(color: secondaryTextColor)),
                        ]
                      );
                    }
                  ),
                  const SizedBox(height: 30),

                  // Appearance Section
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text("Appearance", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: secondaryTextColor)),
                    ),
                  ),
                  
                  _buildSectionContainer(
                    isDark: isDark,
                    child: ListTile(
                      leading: const Icon(Icons.palette_outlined, color: AppTheme.primaryColor),
                      title: Text("Theme", style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
                      trailing: SizedBox(
                        width: 140, // Fixed width for settings dropdown
                        child: LiquidGlassDropdown<ThemeMode>(
                          value: themeNotifier.value,
                          isDark: isDark,
                          items: const [
                            DropdownMenuItem(value: ThemeMode.system, child: Text("System")),
                            DropdownMenuItem(value: ThemeMode.light, child: Text("Light Mode")),
                            DropdownMenuItem(value: ThemeMode.dark, child: Text("Dark Mode")),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              themeNotifier.value = val;
                              setState(() {});
                            }
                          },
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Settings List
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text("General", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: secondaryTextColor)),
                    ),
                  ),

                  _buildSectionContainer(
                    isDark: isDark,
                    child: Column(
                      children: [
                        _buildSettingTile(Icons.notifications_outlined, "Notifications", textColor, isDark, () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()));
                        }),
                        _buildDivider(isDark),
                        _buildSettingTile(Icons.question_answer_outlined, "FAQs", textColor, isDark, () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const FaqsScreen()));
                        }),
                        _buildDivider(isDark),
                        _buildSettingTile(Icons.bug_report_outlined, "Report Bug / Feedback", textColor, isDark, () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedbackScreen()));
                        }),
                        _buildDivider(isDark),
                        _buildSettingTile(Icons.lock_outline, "Manage Password", textColor, isDark, () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const ManagePasswordScreen()));
                        }),
                        _buildDivider(isDark),
                        _buildSettingTile(Icons.support_agent_rounded, "Support", textColor, isDark, () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen()));
                        }),
                        _buildDivider(isDark),
                        _buildSettingTile(Icons.info_outline, "About Clotheline", textColor, isDark, () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()));
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                  
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                          (Route<dynamic> route) => false,
                        );
                      }, 
                      child: const Text("Log Out"),
                    ),
                  )
                ],
              ),
            ),

            Positioned(
              top: 0, left: 0, right: 0,
              child: UnifiedGlassHeader(
                isDark: isDark,
                height: 112,
                title: Text("Settings", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 20)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionContainer({required bool isDark, required Widget child}) {
    if (isDark) {
      return GlassContainer(
        opacity: 0.1,
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: child,
      );
    } else {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
             BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
          ]
        ),
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: child,
      );
    }
  }

  Widget _buildSettingTile(IconData icon, String title, Color textColor, bool isDark, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor),
      title: Text(title, style: TextStyle(color: textColor)),
      trailing: Icon(Icons.arrow_forward_ios, color: isDark ? Colors.white24 : Colors.black12, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey.shade100, indent: 60);
  }
}
