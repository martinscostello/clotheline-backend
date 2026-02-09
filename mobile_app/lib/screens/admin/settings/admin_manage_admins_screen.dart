import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import '../../../widgets/glass/LiquidBackground.dart';
import '../../../widgets/glass/GlassContainer.dart';
import '../../../theme/app_theme.dart';
import 'admin_edit_admin_screen.dart';
import 'package:laundry_app/widgets/common/user_avatar.dart';

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
                                    const Text("Master Admin", style: TextStyle(color: Colors.amber, fontSize: 10, fontStyle: FontStyle.italic)),
                                  if (isRevoked)
                                    const Text("ACCESS REVOKED", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            if (!isMaster) // Cannot edit Master Admin
                                IconButton(
                                icon: const Icon(Icons.edit, color: AppTheme.secondaryColor),
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => AdminEditAdminScreen(admin: admin)
                                  )).then((_) => _fetchAdmins());
                                },
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
