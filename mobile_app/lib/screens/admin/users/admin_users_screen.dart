import 'package:flutter/material.dart';
import 'package:laundry_app/widgets/glass/LiquidBackground.dart';
import 'package:laundry_app/widgets/glass/GlassContainer.dart';
import 'package:laundry_app/theme/app_theme.dart';

import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<dynamic> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final users = await Provider.of<AuthService>(context, listen: false).fetchAllUsers();
      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error fetching users: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    final permissions = currentUser != null ? (currentUser['permissions'] ?? {}) : {};
    final isMaster = currentUser != null && currentUser['isMasterAdmin'] == true;
    final canBroadcast = isMaster || permissions['manageUsers'] == true;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("User Management", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (canBroadcast)
            IconButton(
              icon: const Icon(Icons.campaign, color: AppTheme.primaryColor), 
              onPressed: () {
                _showBroadcastDialog(context);
              },
              tooltip: "Send Bulk Message",
            ),
        ],
      ),
      body: LiquidBackground(
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : _users.isEmpty 
            ? const Center(child: Text("No users found", style: TextStyle(color: Colors.white54)))
            : ListView.builder(
                padding: const EdgeInsets.only(top: 100, bottom: 100, left: 15, right: 15),
                itemCount: _users.length,
                itemBuilder: (context, index) {
                  final user = _users[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: GlassContainer(
                      opacity: 0.1,
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.white10,
                            child: Text(user['name'].toString().substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white)),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user['name'] ?? "Unknown", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                Text(user['email'] ?? "", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                if (user['role'] == 'admin')
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                                      child: const Text("Admin", style: TextStyle(color: Colors.redAccent, fontSize: 10)),
                                    ),
                                  )
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chat_bubble_outline, color: AppTheme.primaryColor),
                            onPressed: () {
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chat feature coming soon!")));
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _showBroadcastDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF101020),
        title: const Text("Broadcast Message", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("This message will be sent to ALL users.", style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Type your announcement...",
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () => Navigator.pop(context), 
            child: const Text("Send", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }
}
