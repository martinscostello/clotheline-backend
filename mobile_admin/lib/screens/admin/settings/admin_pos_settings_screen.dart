import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:clotheline_admin/widgets/glass/LiquidBackground.dart';
import 'package:clotheline_admin/widgets/glass/GlassContainer.dart';
import 'package:clotheline_core/clotheline_core.dart';

import 'admin_branch_pos_config_detail_screen.dart';

class AdminPosSettingsScreen extends StatefulWidget {
  const AdminPosSettingsScreen({super.key});

  @override
  State<AdminPosSettingsScreen> createState() => _AdminPosSettingsScreenState();
}

class _AdminPosSettingsScreenState extends State<AdminPosSettingsScreen> {
  bool _isLoading = false;

  Future<void> _togglePosTerminal(Branch branch) async {
    setState(() => _isLoading = true);
    try {
      final api = ApiService();
      final newValue = !branch.isPosTerminalEnabled;
      final response = await api.client.put('/branches/${branch.id}', data: {
        'isPosTerminalEnabled': newValue,
      });

      if (response.statusCode == 200) {
        if (!mounted) return;
        ToastUtils.show(context, "${branch.name} POS Terminal ${newValue ? 'Enabled' : 'Disabled'}", type: ToastType.success);
        Provider.of<BranchProvider>(context, listen: false).fetchBranches(); // Refresh branches
      } else {
        throw Exception("Failed to update branch");
      }
    } catch (e) {
      if (!mounted) return;
      ToastUtils.show(context, "Error updating branch: $e", type: ToastType.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("POS Terminal Config", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: LiquidBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  "Control which branches have access to the physical POS Terminal Smart Ledger. Tap a branch to configure charges, profit targets, and security controls.",
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ),
              Expanded(
                child: Consumer<BranchProvider>(
                  builder: (context, branchProvider, _) {
                    if (branchProvider.isLoading) {
                      return const Center(child: CircularProgressIndicator(color: AppTheme.secondaryColor));
                    }

                    if (branchProvider.branches.isEmpty) {
                      return const Center(child: Text("No branches found.", style: TextStyle(color: Colors.white54)));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: branchProvider.branches.length,
                      itemBuilder: (context, index) {
                        final branch = branchProvider.branches[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 15),
                          child: GlassContainer(
                            opacity: 0.1,
                            padding: EdgeInsets.zero,
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => AdminBranchPosConfigDetailScreen(branch: branch)),
                                );
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(branch.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                              const SizedBox(width: 8),
                                              const Icon(Icons.settings_outlined, color: Colors.white24, size: 14),
                                            ],
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            branch.isPosTerminalEnabled ? "Terminal Active • Tap to configure" : "Terminal Restricted",
                                            style: TextStyle(
                                              color: branch.isPosTerminalEnabled ? Colors.greenAccent : Colors.redAccent,
                                              fontSize: 11
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Transform.scale(
                                          scale: 0.8,
                                          child: Switch(
                                            value: branch.isPosTerminalEnabled,
                                            activeColor: AppTheme.secondaryColor,
                                            onChanged: _isLoading ? null : (val) => _togglePosTerminal(branch),
                                          ),
                                        ),
                                        const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
