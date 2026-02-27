import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:clotheline_core/clotheline_core.dart';
import '../../../widgets/glass/LiquidBackground.dart';
import '../../../widgets/glass/GlassContainer.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'admin_edit_admin_screen.dart';
import 'package:clotheline_admin/widgets/common/user_avatar.dart';
import 'package:clotheline_core/clotheline_core.dart';

class AdminManageAdminsScreen extends StatefulWidget {
  const AdminManageAdminsScreen({super.key});

  @override
  State<AdminManageAdminsScreen> createState() => _AdminManageAdminsScreenState();
}

class _AdminManageAdminsScreenState extends State<AdminManageAdminsScreen> {
  List<dynamic> _admins = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAdmins();
  }

  Future<void> _fetchAdmins() async {
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final admins = await auth.fetchAdmins();
      final isMaster = auth.currentUser != null && auth.currentUser!['isMasterAdmin'] == true;

      if (mounted) {
        setState(() {
          // [FIX] Master Admin is never visible to other non-master admins
          if (isMaster) {
            _admins = admins;
          } else {
            _admins = admins.where((a) => a['isMasterAdmin'] != true).toList();
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // ToastUtils.show(context, 'Error: $e', type: ToastType.error);
      }
    }
  }

  Future<void> _confirmDeleteAdmin(dynamic admin) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text("Delete Admin", style: TextStyle(color: Colors.white)),
        content: Text("Are you sure you want to permanently delete ${admin['name']}?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      final auth = Provider.of<AuthService>(context, listen: false);
      final success = await auth.deleteAdmin(admin['_id']);
      
      if (mounted) {
        if (success) {
          _fetchAdmins();
        } else {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to delete admin. Permission denied?"))
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text("Manage Administrators", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.add, color: AppTheme.primaryColor), 
              onPressed: () {
                 Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminEditAdminScreen())).then((_) => _fetchAdmins());
              },
              tooltip: "Add Admin",
            ),
          ],
        ),
        body: LiquidBackground(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 100, bottom: 100, left: 15, right: 15),
                  itemCount: _admins.length,
                  itemBuilder: (context, index) {
                    final admin = _admins[index];
                    final isMaster = admin['isMasterAdmin'] == true;
                    final isRevoked = admin['isRevoked'] == true;
  
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: GlassContainer(
                        opacity: 0.1,
                        padding: const EdgeInsets.all(15),
                        child: Row(
                          children: [
                            UserAvatar(
                              avatarId: admin['avatarId'],
                              name: admin['name'] ?? 'A',
                              radius: 20,
                              isDark: true,
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                Text(
                                  admin['name'] ?? 'Unknown',
                                    style: TextStyle(
                                      color: isRevoked ? Colors.redAccent : Colors.white,
                                      fontWeight: FontWeight.bold
                                    )
                                  ),
                                  Text(
                                    admin['email'] ?? '',
                                    style: const TextStyle(color: Colors.white54, fontSize: 12)
                                  ),
                                  if (isMaster)
                                    const Text("Master Admin", style: TextStyle(color: Colors.amber, fontSize: 10, fontStyle: FontStyle.italic))
                                  else if (admin['assignedBranches'] != null && 
                                           admin['assignedBranches'].length >= Provider.of<BranchProvider>(context, listen: false).branches.length &&
                                           Provider.of<BranchProvider>(context, listen: false).branches.isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.green, width: 0.5)
                                      ),
                                      child: const Text("SUPERADMIN", style: TextStyle(color: Colors.green, fontSize: 8, fontWeight: FontWeight.bold)),
                                    ),
                                  if (isRevoked)
                                    const Text("ACCESS REVOKED", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            if (!isMaster) // Cannot edit/delete Master Admin
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: AppTheme.secondaryColor),
                                    onPressed: () {
                                      Navigator.push(context, MaterialPageRoute(
                                        builder: (_) => AdminEditAdminScreen(admin: admin)
                                      )).then((_) => _fetchAdmins());
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    onPressed: () => _confirmDeleteAdmin(admin),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
