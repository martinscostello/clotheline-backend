import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import '../../../widgets/glass/LiquidBackground.dart';
import '../../../widgets/glass/GlassContainer.dart';
import '../../../theme/app_theme.dart';
import 'admin_edit_admin_screen.dart';

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
      final admins = await Provider.of<AuthService>(context, listen: false).fetchAdmins();
      if (mounted) {
        setState(() {
          _admins = admins;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                          CircleAvatar(
                            backgroundColor: isRevoked ? Colors.red.withOpacity(0.2) : Colors.white10,
                            child: Icon(
                                isMaster ? Icons.security : Icons.admin_panel_settings,
                                color: isRevoked ? Colors.red : (isMaster ? Colors.amber : Colors.white)
                            ),
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
    );
  }
}
