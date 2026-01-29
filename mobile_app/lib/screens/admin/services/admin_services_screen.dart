import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../services/laundry_service.dart';
import '../../../../providers/branch_provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/glass/GlassContainer.dart';
import '../../../../widgets/glass/LiquidBackground.dart';
import 'admin_edit_service_screen.dart';

class AdminServicesScreen extends StatefulWidget {
  const AdminServicesScreen({super.key});

  @override
  State<AdminServicesScreen> createState() => _AdminServicesScreenState();
}

class _AdminServicesScreenState extends State<AdminServicesScreen> {
  // We listen to LaundryService for data
  // We use BranchProvider for context
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final branchProvider = Provider.of<BranchProvider>(context, listen: false);
    final laundryService = Provider.of<LaundryService>(context, listen: false);

    // Ensure branches are loaded
    if (branchProvider.branches.isEmpty) {
      await branchProvider.fetchBranches();
    }
    
    // Default to first branch if none selected
    if (branchProvider.selectedBranch == null && branchProvider.branches.isNotEmpty) {
       branchProvider.selectBranch(branchProvider.branches.first);
    }
    
    // Fetch Services for this Branch (Include Hidden so we can Manage them)
    if (branchProvider.selectedBranch != null) {
       await laundryService.fetchServices(branchId: branchProvider.selectedBranch!.id, includeHidden: true);
    } else {
       await laundryService.fetchServices(includeHidden: true); // Global fallback
    }

    if(mounted) setState(() => _isLoading = false);
  }

  Future<void> _onBranchChanged(String? newId) async {
    if (newId == null) return;
    
    setState(() => _isLoading = true);
    final branchProvider = Provider.of<BranchProvider>(context, listen: false);
    final laundryService = Provider.of<LaundryService>(context, listen: false);
    
    // Use Provider to switch branch
    final branch = branchProvider.branches.firstWhere((b) => b.id == newId);
    branchProvider.selectBranch(branch);
    
    // Reload Services Scoped to Branch
    await laundryService.fetchServices(branchId: newId, includeHidden: true);
    
    if(mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text("Manage Services", style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.transparent,
          leading: const BackButton(color: Colors.white),
          actions: [
            // BRANCH SELECTOR
            Consumer<BranchProvider>(
              builder: (context, branchProvider, _) {
                if (branchProvider.branches.isEmpty) return const SizedBox();
                
                return Container(
                  margin: const EdgeInsets.only(right: 15),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20)
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      dropdownColor: const Color(0xFF202020),
                      value: branchProvider.selectedBranch?.id,
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      onChanged: _onBranchChanged,
                      items: branchProvider.branches.map((b) {
                        return DropdownMenuItem(
                          value: b.id,
                          child: Text(b.name, style: const TextStyle(color: Colors.white)),
                        );
                      }).toList(),
                    ),
                  ),
                );
              }
            )
          ],
        ),
        body: LiquidBackground(
          child: Consumer<LaundryService>(
            builder: (context, laundryService, _) {
              if (_isLoading) {
                return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
              }
              
              final services = laundryService.services;
              
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 100, 20, 20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 0.85,
                ),
                itemCount: services.length,
                itemBuilder: (context, index) {
                  final service = services[index];
                  return GestureDetector(
                    onTap: () async {
                      final branchProvider = Provider.of<BranchProvider>(context, listen: false);
                      // Pass Scope!
                      await Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (_) => AdminEditServiceScreen(
                          service: service, 
                          scopeBranch: branchProvider.selectedBranch
                        ))
                      );
                      // Refresh
                      if(branchProvider.selectedBranch != null) {
                        _loadData();
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        image: service.image.startsWith('http') || service.image.startsWith('assets') ? DecorationImage(
                          image: service.image.startsWith('http') ? NetworkImage(service.image) : AssetImage(service.image) as ImageProvider,
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.darken),
                        ) : null,
                      ),
                      child: GlassContainer(
                        opacity: 0.05, 
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Icon
                            if (!service.image.startsWith('http')) 
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Color(int.parse(service.color.replaceAll('#', '0xFF'))).withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _getIconData(service.icon),
                                  color: Color(int.parse(service.color.replaceAll('#', '0xFF'))),
                                  size: 32,
                                ),
                              ),
                            const SizedBox(height: 12),
                            // Name
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Text(
                                service.name,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            // Status Badge
                            const SizedBox(height: 8),
                            if (service.isLocked)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(4)),
                                child: Text(service.lockedLabel, style: const TextStyle(color: Colors.white, fontSize: 10)),
                              )
                            else if (service.discountPercentage > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                                child: Text("-${service.discountPercentage}% OFF", style: const TextStyle(color: Colors.white, fontSize: 10)),
                              )
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            }
          ),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppTheme.primaryColor,
          child: const Icon(Icons.add, color: Colors.white),
          onPressed: () async {
            final branchProvider = Provider.of<BranchProvider>(context, listen: false);
            await Navigator.push(
              context, 
              MaterialPageRoute(builder: (_) => AdminEditServiceScreen(
                service: null, // Create Mode
                scopeBranch: branchProvider.selectedBranch
              ))
            );
            // Refresh
            _loadData(); // Reloads all
          },
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'dry_cleaning': return Icons.dry_cleaning;
      case 'local_laundry_service': return Icons.local_laundry_service;
      case 'do_not_step': return Icons.do_not_step;
      case 'water_drop': return Icons.water_drop;
      case 'house': return Icons.house;
      default: return Icons.category;
    }
  }
}
