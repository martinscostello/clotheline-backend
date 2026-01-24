import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/cart_service.dart';
import '../../services/auth_service.dart';
import '../../providers/branch_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass/GlassContainer.dart';
import '../../widgets/glass/LaundryGlassBackground.dart';
import '../user/main_layout.dart';

class BranchSelectionScreen extends StatelessWidget {
  final bool isModal; // If true, pops on selection instead of replacement
  
  const BranchSelectionScreen({super.key, this.isModal = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white54 : Colors.black54;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Select your City", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textColor), // Back button color
      ),
      body: LaundryGlassBackground(
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 100),
              itemCount: provider.branches.length,
              itemBuilder: (context, index) {
                final branch = provider.branches[index];
                final isSelected = provider.selectedBranch?.id == branch.id;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: GestureDetector(
                    onTap: () async {
                       final cartService = Provider.of<CartService>(context, listen: false);
                       
                       // Helper to Navigate
                       void navigateAway() {
                         if (isModal) {
                           Navigator.pop(context);
                         } else {
                           Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainLayout()));
                         }
                       }

                       if (cartService.validateBranch(branch.id)) {
                          // Safe to switch
                          cartService.setBranch(branch.id);
                          await provider.selectBranch(branch);
                          navigateAway();
                       } else {
                          // Mismatch - Show Dialog
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
                    child: GlassContainer(
                      // [FIX] Super App Glass Values
                      opacity: isSelected ? (isDark ? 0.25 : 0.15) : (isDark ? 0.2 : 0.1),
                      padding: const EdgeInsets.all(20),
                      border: Border.all(
                        color: isSelected 
                           ? AppTheme.primaryColor 
                           : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1)),
                        width: 1
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_city, 
                            color: isSelected ? AppTheme.primaryColor : (isDark ? Colors.white54 : Colors.black45),
                            size: 30
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  branch.name, 
                                  style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  branch.address,
                                  style: TextStyle(color: subtitleColor, fontSize: 12)
                                ),
                              ],
                            ),
                          ),
                          if (isSelected) 
                             const Icon(Icons.check_circle, color: AppTheme.primaryColor)
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
    );
  }
}
