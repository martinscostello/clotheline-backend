import 'package:laundry_app/main.dart'; // Access themeNotifier
import 'package:flutter/material.dart';
import 'package:laundry_app/theme/app_theme.dart';
import 'package:laundry_app/screens/auth/login_screen.dart';
import 'package:laundry_app/widgets/glass/LaundryGlassCard.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import 'notification_settings_screen.dart';
import 'faqs_screen.dart'; // Added Import
import 'feedback_screen.dart'; // Added Import
import 'about_screen.dart'; // Added Import
import 'manage_addresses_screen.dart';
import 'package:laundry_app/widgets/glass/UnifiedGlassHeader.dart';
import 'package:laundry_app/widgets/common/user_avatar.dart';
import 'manage_account_screen.dart';
import 'support_hub_screen.dart';
import '../../../widgets/dialogs/guest_login_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  void _showAvatarPicker(BuildContext context, AuthService auth, bool isDark) {
    final isAdmin = auth.currentUser?['role'] == 'admin';
    final userAvatars = List.generate(20, (i) => 'u_${i + 1}'); // [FIX] Range matched to 20
    final adminAvatars = List.generate(10, (i) => 'a_${i + 1}');
    final avatars = isAdmin ? adminAvatars : userAvatars;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: 400,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black12, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text("Select Your Avatar", style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 15, crossAxisSpacing: 15),
                itemCount: 20, // [FIX] Updated to full 20 avatars
                itemBuilder: (context, index) {
                  final avatarId = avatars[index];
                  final isSelected = auth.currentUser?['avatarId'] == avatarId;
                  return GestureDetector(
                    onTap: () {
                      auth.updateAvatar(avatarId);
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: isSelected ? AppTheme.primaryColor : Colors.transparent, width: 2),
                      ),
                      child: UserAvatar(avatarId: avatarId, name: isAdmin ? "Admin" : "User", radius: 30, isDark: isDark),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Stack(
          children: [
            SingleChildScrollView(
              physics: const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics()), // [FIX] Prevent overscroll void
              padding: const EdgeInsets.only(top: 120, bottom: 120, left: 16, right: 16), // [TIGHTER]
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Profile Header
                  Consumer<AuthService>(
                    builder: (context, auth, _) {
                       final user = auth.currentUser;
                      String name = user?['name']?.toString() ?? '';
                      String email = user?['email']?.toString() ?? '';
                      
                      // If name/email is empty but logged in, it might be a newly created user 
                      // where the profile hasn't hydrated yet (Ghost).
                      if (!auth.isGuest && (name.isEmpty || email.isEmpty)) {
                         name = "Valued Customer";
                         email = "Updating profile...";
                         WidgetsBinding.instance.addPostFrameCallback((_) {
                           auth.validateSession(); 
                         });
                      }
                      if (auth.isGuest) {
                         name = "Guest User";
                         email = "Sign in to save progress";
                      }
                      
                      return Column(
                        children: [
                          Stack(
                            children: [
                              UserAvatar(
                                avatarId: user?['avatarId'],
                                name: name,
                                radius: 45,
                                isDark: isDark,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () => _showAvatarPicker(context, auth, isDark),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: isDark ? const Color(0xFF1E1E2C) : Colors.white, width: 2),
                                    ),
                                    child: const Icon(Icons.edit, size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(name, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(email, style: TextStyle(color: secondaryTextColor, fontSize: 14)),
                        ]
                      );
                    }
                  ),
                  const SizedBox(height: 20), // [REDUCED]

                  // Appearance Section
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text("Appearance", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: secondaryTextColor)),
                    ),
                  ),
                  
                  _buildSectionContainer(
                    isDark: isDark,
                    child: ListTile(
                      dense: true, // [TIGHTER]
                      leading: const Icon(Icons.palette_outlined, color: AppTheme.primaryColor),
                      title: Text("Theme", style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
                      trailing: SizedBox(
                        width: 130, // [TIGHTER]
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<ThemeMode>(
                              value: themeNotifier.value,
                              dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                              icon: Icon(Icons.keyboard_arrow_down, size: 18, color: textColor),
                              style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w500),
                              items: const [
                                DropdownMenuItem(value: ThemeMode.system, child: Text("System")),
                                DropdownMenuItem(value: ThemeMode.light, child: Text("Light")),
                                DropdownMenuItem(value: ThemeMode.dark, child: Text("Dark")),
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
                    ),
                  ),

                  const SizedBox(height: 15), // [REDUCED]

                  // Settings List
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text("General", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: secondaryTextColor)),
                    ),
                  ),

                  Consumer<AuthService>(
                    builder: (context, auth, _) => _buildSectionContainer(
                      isDark: isDark,
                      child: Column(
                        children: [
                          _buildSettingTile(Icons.notifications_outlined, "Notifications", textColor, isDark, () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()));
                          }),
                          _buildDivider(isDark),
                          _buildSettingTile(Icons.bookmark_outline, "Manage Addresses", textColor, isDark, () {
                            if (auth.isGuest) {
                              _showGuestLoginDialog(context, "Please sign in to manage your addresses.");
                              return;
                            }
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageAddressesScreen()));
                          }),
                          _buildDivider(isDark),
                          _buildSettingTile(Icons.question_answer_outlined, "FAQs", textColor, isDark, () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const FaqsScreen()));
                          }),
                          _buildDivider(isDark),
                          _buildSettingTile(Icons.bug_report_outlined, "Report Bug / Feedback", textColor, isDark, () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedbackScreen()));
                          }),
                          _buildDivider(isDark), // [NEW] Divider requested by user
                          _buildSettingTile(Icons.person_outline, "Manage Account", textColor, isDark, () {
                            if (auth.isGuest) {
                              _showGuestLoginDialog(context, "Please sign in to manage your account.");
                              return;
                            }
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageAccountScreen()));
                          }),
                          _buildDivider(isDark),
                          _buildSettingTile(Icons.support_agent_rounded, "Support", textColor, isDark, () {
                            if (auth.isGuest) {
                              _showGuestLoginDialog(context, "Please sign in to contact support.");
                              return;
                            }
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportHubScreen()));
                          }),
                          _buildDivider(isDark),
                          _buildSettingTile(Icons.info_outline, "About Clotheline", textColor, isDark, () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()));
                          }),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 25), // [REDUCED]
                  
                  SizedBox(
                    width: double.infinity,
                    height: 50, // [FIXED HEIGHT]
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
                height: 100, // [TIGHTER]
                title: Text("Settings", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)), // [SMALLER]
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildSectionContainer({required bool isDark, required Widget child}) {
    return LaundryGlassCard(
      opacity: isDark ? 0.12 : 0.05,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: child,
    );
  }

  Widget _buildSettingTile(IconData icon, String title, Color textColor, bool isDark, VoidCallback onTap) {
    return ListTile(
      dense: true, // [TIGHTER]
      minLeadingWidth: 20, // [TIGHTER]
      leading: Icon(icon, color: AppTheme.primaryColor, size: 20), // [SMALLER]
      title: Text(title, style: TextStyle(color: textColor, fontSize: 14)), // [SMALLER]
      trailing: Icon(Icons.arrow_forward_ios, color: isDark ? Colors.white24 : Colors.black12, size: 14),
      onTap: onTap,
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey.shade100, indent: 60);
  }

  void _showGuestLoginDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => GuestLoginDialog(message: message),
    );
  }
}
