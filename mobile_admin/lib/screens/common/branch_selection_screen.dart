import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import '../../widgets/glass/LaundryGlassCard.dart';
import '../../widgets/glass/LaundryGlassBackground.dart';
import '../../widgets/glass/UnifiedGlassHeader.dart';
import 'package:clotheline_admin/screens/admin/admin_main_layout.dart';

class BranchSelectionScreen extends StatefulWidget {
  final bool isModal; // If true, pops on selection instead of replacement
  
  const BranchSelectionScreen({super.key, this.isModal = false});

  @override
  State<BranchSelectionScreen> createState() => _BranchSelectionScreenState();
}

class _BranchSelectionScreenState extends State<BranchSelectionScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-refresh logic: Fetch branches on load to avoid empty pages
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<BranchProvider>(context, listen: false);
      if (provider.branches.isEmpty) {
        provider.fetchBranches();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white54 : Colors.black54;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          LaundryGlassBackground(
            child: Consumer<BranchProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
                }
                
                if (provider.branches.isEmpty) {
                   return Center(
                     child: Column(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                         Icon(Icons.location_off, size: 60, color: isDark ? Colors.white38 : Colors.grey),
                         const SizedBox(height: 15),
                         Text("No branches found", style: TextStyle(color: subtitleColor)),
                         const SizedBox(height: 10),
                         TextButton.icon(
                           icon: const Icon(Icons.refresh, color: AppTheme.primaryColor),
                           label: const Text("Retry", style: TextStyle(color: AppTheme.primaryColor)),
                           onPressed: () => provider.fetchBranches(),
                         ),
                         const SizedBox(height: 20),
                         TextButton.icon(
                            icon: const Icon(Icons.logout, color: Colors.redAccent),
                            label: const Text("Logout (Reset)", style: TextStyle(color: Colors.redAccent)),
                            onPressed: () async {
                               await Provider.of<AuthService>(context, listen: false).logout();
                               Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
                            }
                         )
                       ],
                     ),
                   );
                }
                
                return ListView.builder(
                  padding: EdgeInsets.only(top: topPadding + 110, bottom: 40, left: 16, right: 16),
                  itemCount: provider.branches.length,
                  itemBuilder: (context, index) {
                    final branch = provider.branches[index];
                    final isSelected = provider.selectedBranch?.id == branch.id;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: GestureDetector(
                        onTap: () async {
                           final cartService = Provider.of<CartService>(context, listen: false);
                           
                           // Helper to Navigate
                           void navigateAway() {
                             if (widget.isModal) {
                               Navigator.pop(context);
                             } else {
                               Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminMainLayout()));
                             }
                           }

                           if (cartService.validateBranch(branch.id)) {
                              cartService.setBranch(branch.id);
                              await provider.selectBranch(branch);
                              navigateAway();
                           } else {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                                  title: Text("Switch Branch?", style: TextStyle(color: textColor)),
                                  content: Text("Switching branches will clear your current cart. Continue?", style: TextStyle(color: subtitleColor)),
                                  actions: [
                                    TextButton(
                                      child: const Text("Cancel"), 
                                      onPressed: () => Navigator.pop(ctx, false)
                                    ),
                                    TextButton(
                                      child: const Text("Clear & Switch", style: TextStyle(color: Colors.red)), 
                                      onPressed: () => Navigator.pop(ctx, true)
                                    ),
                                  ],
                                )
                              );
                              
                              if (confirm == true) {
                                 cartService.clearCart();
                                 cartService.setBranch(branch.id);
                                 await provider.selectBranch(branch);
                                 navigateAway();
                              }
                           }
                        },
                        child: LaundryGlassCard(
                          opacity: isSelected ? 0.15 : 0.10,
                          padding: const EdgeInsets.all(16),
                          border: Border.all(
                            color: isSelected 
                               ? AppTheme.primaryColor 
                               : (isDark ? Colors.white10 : Colors.black12),
                            width: isSelected ? 1.5 : 0.5
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.location_city_rounded, 
                                  color: isSelected ? AppTheme.primaryColor : (isDark ? Colors.white54 : Colors.black45),
                                  size: 24
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      branch.name, 
                                      style: TextStyle(color: textColor, fontSize: 17, fontWeight: FontWeight.bold)
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      branch.address,
                                      style: TextStyle(color: subtitleColor, fontSize: 12)
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected) 
                                 const Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 24)
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Positioned(
            top: 0, left: 0, right: 0,
            child: UnifiedGlassHeader(
              isDark: isDark,
              onBack: widget.isModal ? () => Navigator.pop(context) : null,
              title: Text("Select your City", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }
}
