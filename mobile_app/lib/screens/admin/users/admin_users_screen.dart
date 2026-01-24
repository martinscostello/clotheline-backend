import 'package:flutter/material.dart';
import 'package:laundry_app/widgets/glass/LiquidBackground.dart';
import 'package:laundry_app/widgets/glass/GlassContainer.dart';
import 'package:laundry_app/theme/app_theme.dart';

import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import '../../../utils/toast_utils.dart';
import '../../../services/chat_service.dart';
import '../../../providers/branch_provider.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<dynamic> _users = [];
  bool _isLoading = true;
  final Set<String> _selectedUserIds = {};
  bool _isSelectionMode = false;

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
        ToastUtils.show(context, "Error fetching users: $e", type: ToastType.error);
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
        title: Text(_isSelectionMode ? "${_selectedUserIds.length} Selected" : "User Management", 
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _isSelectionMode 
          ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() { _isSelectionMode = false; _selectedUserIds.clear(); }))
          : null,
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.campaign, color: AppTheme.primaryColor), 
              onPressed: _selectedUserIds.isEmpty ? null : () => _showBroadcastDialog(context, isSelectedOnly: true),
              tooltip: "Broadcast to Selected",
            )
          else if (canBroadcast)
            IconButton(
              icon: const Icon(Icons.campaign, color: AppTheme.primaryColor), 
              onPressed: () => _showBroadcastDialog(context, isSelectedOnly: false),
              tooltip: "Broadcast to All",
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
                  final userId = user['_id'].toString();
                  final isSelected = _selectedUserIds.contains(userId);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: GestureDetector(
                      onLongPress: () {
                        setState(() {
                          _isSelectionMode = true;
                          _selectedUserIds.add(userId);
                        });
                      },
                      onTap: () {
                        if (_isSelectionMode) {
                          setState(() {
                            if (isSelected) {
                              _selectedUserIds.remove(userId);
                              if (_selectedUserIds.isEmpty) _isSelectionMode = false;
                            } else {
                              _selectedUserIds.add(userId);
                            }
                          });
                        }
                      },
                      child: GlassContainer(
                        opacity: isSelected ? 0.2 : 0.1,
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                        child: Row(
                          children: [
                            if (_isSelectionMode)
                              Padding(
                                padding: const EdgeInsets.only(right: 15),
                                child: Icon(
                                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                  color: isSelected ? AppTheme.primaryColor : Colors.white30,
                                ),
                              ),
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
                            if (!_isSelectionMode)
                              IconButton(
                                icon: const Icon(Icons.chat_bubble_outline, color: AppTheme.primaryColor),
                                onPressed: () {
                                   // Quick navigation to user thread could be added here
                                   ToastUtils.show(context, "Direct chat coming soon", type: ToastType.info);
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _showBroadcastDialog(BuildContext context, {required bool isSelectedOnly}) {
    final controller = TextEditingController();
    bool isSending = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF101020),
          title: Text(isSelectedOnly ? "Broadcast to Selected" : "Broadcast to All", style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isSelectedOnly 
                  ? "This message will be sent to ${_selectedUserIds.length} users." 
                  : "This message will be sent to ALL users in the active branch.", 
                style: const TextStyle(color: Colors.white54, fontSize: 12)
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                maxLines: 4,
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
            TextButton(
              onPressed: isSending ? null : () => Navigator.pop(context), 
              child: const Text("Cancel")
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                disabledBackgroundColor: Colors.grey.withOpacity(0.1)
              ),
              onPressed: isSending ? null : () async {
                final text = controller.text.trim();
                if (text.isEmpty) return;

                setDialogState(() => isSending = true);
                
                try {
                  final branchProvider = Provider.of<BranchProvider>(context, listen: false);
                  if (branchProvider.selectedBranch == null) {
                    ToastUtils.show(context, "Please select a branch first", type: ToastType.error);
                    return;
                  }

                  await Provider.of<ChatService>(context, listen: false).sendBroadcast(
                    branchId: branchProvider.selectedBranch!.id,
                    messageText: text,
                    audienceType: isSelectedOnly ? 'selected' : 'all',
                    targetUserIds: isSelectedOnly ? _selectedUserIds.toList() : null
                  );

                  if (context.mounted) {
                    Navigator.pop(context);
                    ToastUtils.show(context, "Broadcast sent successfully!", type: ToastType.success);
                    setState(() {
                      _isSelectionMode = false;
                      _selectedUserIds.clear();
                    });
                  }
                } catch (e) {
                  if (context.mounted) {
                     setDialogState(() => isSending = false);
                     ToastUtils.show(context, "Failed to send broadcast", type: ToastType.error);
                  }
                }
              }, 
              child: isSending 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Text("Send", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
