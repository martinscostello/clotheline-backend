import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import '../../../providers/branch_provider.dart';
import '../../../widgets/glass/LiquidBackground.dart';
import '../../../widgets/glass/GlassContainer.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/toast_utils.dart';

class AdminNotificationSettingsScreen extends StatefulWidget {
  const AdminNotificationSettingsScreen({super.key});

  @override
  State<AdminNotificationSettingsScreen> createState() => _AdminNotificationSettingsScreenState();
}

class _AdminNotificationSettingsScreenState extends State<AdminNotificationSettingsScreen> {
  bool _isSaving = false;
  Map<String, dynamic> _prefs = {};
  List<String> _subscribedBranches = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.currentUser;
    if (user != null) {
      _prefs = Map<String, dynamic>.from(user['adminNotificationPreferences'] ?? {});
      _subscribedBranches = List<String>.from(user['adminNotificationPreferences']?['subscribedBranches'] ?? []);
      
      // Defaults if empty
      _prefs['newOrder'] ??= true;
      _prefs['newChat'] ??= true;
      _prefs['systemAlerts'] ??= true;
      _prefs['quietHoursEnabled'] ??= false;
      _prefs['quietHoursStart'] ??= '22:00';
      _prefs['quietHoursEnd'] ??= '07:00';
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final auth = Provider.of<AuthService>(context, listen: false);
    
    _prefs['subscribedBranches'] = _subscribedBranches;
    
    final success = await auth.updateAdminNotificationPreferences(_prefs);
    
    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        ToastUtils.show(context, "Preferences Saved!", type: ToastType.success);
      } else {
        ToastUtils.show(context, "Failed to save. Check server.", type: ToastType.error);
      }
    }
  }

  Future<void> _selectTime(bool isStart) async {
    final key = isStart ? 'quietHoursStart' : 'quietHoursEnd';
    final current = _prefs[key] as String;
    final parts = current.split(':');
    final time = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    
    final picked = await showTimePicker(
      context: context,
      initialTime: time,
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.primaryColor,
            onPrimary: Colors.black,
            surface: Color(0xFF1E1E2C),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        _prefs[key] = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text("Notification Settings", style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.transparent,
          actions: [
            if (_isSaving)
              const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
            else
              TextButton(
                onPressed: _save,
                child: const Text("SAVE", style: TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold)),
              )
          ],
        ),
        body: LiquidBackground(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 110, 20, 50),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader("Event Alerts"),
                GlassContainer(
                  opacity: 0.1,
                  child: Column(
                    children: [
                      _buildToggle("New Orders", "Notify when a walk-in or pickup is created", _prefs['newOrder'], (val) => setState(() => _prefs['newOrder'] = val)),
                      _buildToggle("Chat Messages", "New messages from customers", _prefs['newChat'], (val) => setState(() => _prefs['newChat'] = val)),
                      _buildToggle("System Alerts", "Warnings, permission violations, server news", _prefs['systemAlerts'], (val) => setState(() => _prefs['systemAlerts'] = val)),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                _buildSectionHeader("Quiet Hours"),
                GlassContainer(
                  opacity: 0.1,
                  child: Column(
                    children: [
                      _buildToggle("Enable DND Schedule", "Silence notifications during specific hours", _prefs['quietHoursEnabled'], (val) => setState(() => _prefs['quietHoursEnabled'] = val)),
                      if (_prefs['quietHoursEnabled']) ...[
                        const Divider(color: Colors.white10),
                        _buildTimePicker("Start Time", _prefs['quietHoursStart'], () => _selectTime(true)),
                        _buildTimePicker("End Time", _prefs['quietHoursEnd'], () => _selectTime(false)),
                      ]
                    ],
                  ),
                ),

                const SizedBox(height: 30),
                _buildSectionHeader("Branch Selection"),
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 8),
                  child: Text("Select which branches you want to receive alerts for. Empty means all visible branches.", style: TextStyle(color: Colors.white54, fontSize: 12)),
                ),
                Consumer<BranchProvider>(
                  builder: (context, branchProvider, _) {
                    final branches = branchProvider.branches;
                    return GlassContainer(
                      opacity: 0.1,
                      child: Column(
                        children: branches.map((branch) {
                          final isSelected = _subscribedBranches.contains(branch.id);
                          return CheckboxListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                            title: Text(branch.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
                            value: isSelected,
                            activeColor: AppTheme.primaryColor,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _subscribedBranches.add(branch.id);
                                } else {
                                  _subscribedBranches.remove(branch.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(title, style: const TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }

  Widget _buildToggle(String title, String subtitle, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      value: value,
      activeColor: AppTheme.primaryColor,
      onChanged: onChanged,
    );
  }

  Widget _buildTimePicker(String label, String time, VoidCallback onTap) {
    return ListTile(
      title: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
        child: Text(time, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      onTap: onTap,
    );
  }
}
