import 'package:flutter/material.dart';
import 'package:laundry_app/widgets/glass/LiquidBackground.dart';
import 'package:laundry_app/widgets/glass/GlassContainer.dart';
import 'package:laundry_app/theme/app_theme.dart';

import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import '../../../utils/toast_utils.dart';
import '../../../services/chat_service.dart';
import '../../../providers/branch_provider.dart';
import 'admin_user_profile_screen.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<dynamic> _allUsers = []; // Store full list
  List<dynamic> _filteredUsers = []; // Store filtered list
  bool _isLoading = true;
  final Set<String> _selectedUserIds = {};
  bool _isSelectionMode = false;
  final TextEditingController _searchController = TextEditingController();
  String? _selectedBranchId; // [New]

  @override
  void initState() {
    super.initState();
    // [FIX] Initialize from current global branch selection
    final bp = Provider.of<BranchProvider>(context, listen: false);
    _selectedBranchId = bp.selectedBranch?.id;

    _fetchUsers();
    _searchController.addListener(_filterUsers);
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final users = await auth.fetchAllUsers(branchId: _selectedBranchId);
      
      if (mounted) {
        setState(() {
          _allUsers = users;
          _filteredUsers = users;
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

  void _onBranchChanged(String? newBranchId) {
    if (_selectedBranchId == newBranchId) return;
    setState(() {
      _selectedBranchId = newBranchId;
      _isLoading = true;
    });
    _fetchUsers();
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = _allUsers.where((user) {
        // [FIX] Double protection: Filter out admins here too
        if (user['role'] == 'admin') return false;

        final name = (user['name'] ?? "").toLowerCase();
        final email = (user['email'] ?? "").toLowerCase();
        final phone = (user['phone'] ?? "").toLowerCase();
        return name.contains(query) || email.contains(query) || phone.contains(query);
      }).toList();
    });
  }

  void _openProfile(Map<String, dynamic> user) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdminUserProfileScreen(user: user)),
    );
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
        title: _isSelectionMode 
           ? Text("${_selectedUserIds.length} Selected", style: const TextStyle(color: Colors.white))
           : TextField(
               controller: _searchController,
               style: const TextStyle(color: Colors.white),
               decoration: const InputDecoration(
                 hintText: "Search Users...",
                 hintStyle: TextStyle(color: Colors.white54),
                 border: InputBorder.none,
                 icon: Icon(Icons.search, color: Colors.white54),
               ),
             ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _isSelectionMode 
          ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() { _isSelectionMode = false; _selectedUserIds.clear(); }))
          : const BackButton(color: Colors.white),
        actions: [
          if (!_isSelectionMode)
            Consumer<BranchProvider>(
              builder: (context, branchProvider, _) {
                if (branchProvider.branches.isEmpty) return const SizedBox.shrink();
                return DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    dropdownColor: const Color(0xFF2C2C2E),
                    value: _selectedBranchId,
                    hint: const Icon(Icons.store, color: AppTheme.secondaryColor, size: 20),
                    icon: const SizedBox.shrink(),
                    onChanged: _onBranchChanged,
                    items: [
                      const DropdownMenuItem<String?>(
                         value: null, 
                         child: Text("All", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))
                      ),
                      ...branchProvider.branches.map((b) => DropdownMenuItem(
                        value: b.id,
                        child: Text(b.name, style: const TextStyle(color: Colors.white70, fontSize: 12))
                      ))
                    ],
                  ),
                );
              }
            ),
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
          : _filteredUsers.isEmpty 
            ? const Center(child: Text("No users found", style: TextStyle(color: Colors.white54)))
            : ListView.builder(
                padding: const EdgeInsets.only(top: 100, bottom: 100, left: 15, right: 15),
                itemCount: _filteredUsers.length,
                itemBuilder: (context, index) {
                  final user = _filteredUsers[index];
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
                        } else {
                          _openProfile(user);
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
                            if (!_isSelectionMode) ...[
                              if (isMaster && user['isMasterAdmin'] != true)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                  onPressed: () => _confirmDeleteUser(context, user),
                                ),
                              const Icon(Icons.chevron_right, color: Colors.white24),
                            ],
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

  void _confirmDeleteUser(BuildContext context, dynamic user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF101020),
        title: const Text("Wipe User?", style: TextStyle(color: Colors.white)),
        content: Text(
          "Are you sure you want to completely remove ${user['name']} from the face of the app? This action is permanent.",
          style: const TextStyle(color: Colors.white54),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              final success = await Provider.of<AuthService>(context, listen: false).deleteUser(user['_id'].toString());
              if (success) {
                if (context.mounted) {
                  ToastUtils.show(context, "User wiped from existence!", type: ToastType.success);
                  _fetchUsers(); // Refresh list
                }
              } else {
                if (context.mounted) {
                  ToastUtils.show(context, "Failed to delete user", type: ToastType.error);
                }
              }
            },
            child: const Text("Wipe Now", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
