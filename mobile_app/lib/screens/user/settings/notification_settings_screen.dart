import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {

  @override
  void initState() {
    super.initState();
    // Fetch fresh prefs when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotificationService>(context, listen: false).fetchPreferences();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Notification Settings", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Consumer<NotificationService>(
        builder: (context, notifService, _) {
          final prefs = notifService.preferences;
          // Helper to safely get bool
          bool get(String key) => prefs[key] == true;

          return SingleChildScrollView(
            padding: const EdgeInsets.only(top: 100, left: 20, right: 20),
            child: Column(
              children: [
                _buildSection(isDark, [
                  SwitchListTile(
                    title: Text("Enable Notifications", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                    activeColor: AppTheme.primaryColor,
                    value: get('push'), // Mapping 'push' as master toggle for now
                    onChanged: (val) => notifService.updatePreference('push', val),
                    secondary: const Icon(Icons.notifications_active_outlined, color: AppTheme.primaryColor),
                  ),
                ]),
                
                const SizedBox(height: 20),
                
                if (get('push')) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Types", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black54)),
                  ),
                  const SizedBox(height: 10),
                  
                  _buildSection(isDark, [
                    SwitchListTile(
                      title: Text("Admin Broadcasts", style: TextStyle(color: textColor)),
                      subtitle: Text("News and announcements", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
                      activeColor: Colors.purpleAccent,
                      value: get('adminBroadcasts'),
                      onChanged: (val) => notifService.updatePreference('adminBroadcasts', val),
                    ),
                    Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200], indent: 16, endIndent: 16),
                    SwitchListTile(
                      title: Text("Order Updates", style: TextStyle(color: textColor)),
                      subtitle: Text("Status changes and delivery", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
                      activeColor: Colors.blueAccent,
                      value: get('orderUpdates'),
                      onChanged: (val) => notifService.updatePreference('orderUpdates', val),
                    ),
                    Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200], indent: 16, endIndent: 16),
                    SwitchListTile(
                      title: Text("Bucket Updates", style: TextStyle(color: textColor)),
                      subtitle: Text("Items added/removed", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
                      activeColor: Colors.orangeAccent,
                      value: get('bucketUpdates'),
                      onChanged: (val) => notifService.updatePreference('bucketUpdates', val),
                    ),
                  ]),
                  
                  const SizedBox(height: 20),
                  
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Preferences", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black54)),
                  ),
                  const SizedBox(height: 10),
  
                   _buildSection(isDark, [
                    ListTile(
                      title: Text("Notification Sound", style: TextStyle(color: textColor)),
                      trailing: DropdownButton<String>(
                        dropdownColor: isDark ? Colors.grey[900] : Colors.white,
                        value: "Chime", // Mock for now or store in prefs
                        style: TextStyle(color: textColor),
                        underline: const SizedBox(),
                        items: ["Default", "Chime", "Soft", "Alert"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (val) {}, // No backend field yet
                      ),
                      leading: const Icon(Icons.music_note_outlined, color: AppTheme.primaryColor),
                    ),
                  ]),
                ]
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildSection(bool isDark, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? [] : [
           BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
        ]
      ),
      child: Column(children: children),
    );
  }
}
