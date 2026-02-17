import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../services/laundry_service.dart';
import '../../../../providers/branch_provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/glass/GlassContainer.dart';
import '../../../../widgets/glass/LiquidBackground.dart';
import 'admin_edit_service_screen.dart';
import '../../../../models/service_model.dart';

class AdminServicesScreen extends StatelessWidget {
  const AdminServicesScreen({super.key});

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
        ),
        body: const LiquidBackground(
          child: AdminServicesBody(),
        ),
      ),
    );
  }
}

class AdminServicesBody extends StatefulWidget {
  final bool isEmbedded;
  final Function(String, Map<String, dynamic>)? onNavigate;
  const AdminServicesBody({super.key, this.isEmbedded = false, this.onNavigate});

  @override
  State<AdminServicesBody> createState() => _AdminServicesBodyState();
}

class _AdminServicesBodyState extends State<AdminServicesBody> {
  // We listen to LaundryService for data
  // We use BranchProvider for context
  bool _isLoading = false;
  bool _isEditMode = false; // [NEW]

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

  void _toggleEditMode() {
    setState(() => _isEditMode = !_isEditMode);
  }

  Future<void> _deleteService(ServiceModel service) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text("Delete Service?", style: TextStyle(color: Colors.white)),
        content: Text("Are you sure you want to delete '${service.name}'? This action cannot be undone.", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent))
          ),
        ],
      )
    );

    if (confirm == true) {
      final laundryService = Provider.of<LaundryService>(context, listen: false);
      final success = await laundryService.deleteService(service.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${service.name} deleted")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Consumer<LaundryService>(
          builder: (context, laundryService, _) {
            if (_isLoading) {
              return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
            }
            
            final services = laundryService.services;

            if (_isEditMode) {
              return ReorderableListView.builder(
                padding: EdgeInsets.fromLTRB(20, widget.isEmbedded ? 20 : 100, 20, 20),
                itemCount: services.length,
                itemBuilder: (context, index) {
                  final service = services[index];
                  return _buildServiceEditTile(service, index);
                },
                onReorder: (oldIndex, newIndex) {
                  if (newIndex > oldIndex) newIndex -= 1;
                  if (oldIndex == newIndex) return;
                  
                  final items = List<ServiceModel>.from(services);
                  final item = items.removeAt(oldIndex);
                  items.insert(newIndex, item);
                  laundryService.updateServiceOrder(items);
                },
              );
            }
            
            return GridView.builder(
              padding: EdgeInsets.fromLTRB(20, widget.isEmbedded ? 20 : 100, 20, 120),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                childAspectRatio: 0.8, 
              ),
              itemCount: services.length,
              itemBuilder: (context, index) {
                final service = services[index];
                return _buildServiceCard(service);
              },
            );
          }
        ),
        // Positioned controls if embedded (Optional: maybe keep them in AppBar?)
        // For now, I'll provide an embedded version that might not have the branch selector in body
        // but maybe we need it.
        if (!widget.isEmbedded)
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            right: 20,
            child: _buildBodyControls(),
          ),
        
        // FAB equivalent
        Positioned(
          bottom: 20,
          right: 20,
          child: FloatingActionButton(
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
              _loadData();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBodyControls() {
    return Row(
      children: [
        IconButton(
          icon: Icon(_isEditMode ? Icons.check : Icons.edit, color: Colors.white),
          onPressed: _toggleEditMode,
        ),
        Consumer<BranchProvider>(
          builder: (context, branchProvider, _) {
            if (branchProvider.branches.isEmpty) return const SizedBox();
            return Container(
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
                  onChanged: _onBranchChanged,
                  items: branchProvider.branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name, style: const TextStyle(color: Colors.white)))).toList(),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildServiceCard(ServiceModel service) {
    return GestureDetector(
      onTap: () async {
        final branchProvider = Provider.of<BranchProvider>(context, listen: false);
        if (widget.isEmbedded && widget.onNavigate != null) {
          widget.onNavigate!('edit_service', {
            'service': service,
            'scopeBranch': branchProvider.selectedBranch,
          });
        } else {
          await Navigator.push(
            context, 
            MaterialPageRoute(builder: (_) => AdminEditServiceScreen(
              service: service, 
              scopeBranch: branchProvider.selectedBranch
            ))
          );
          _loadData();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF1E1E2C),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            // IMAGE AT TOP
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  image: DecorationImage(
                    image: service.image.startsWith('http') 
                        ? NetworkImage(service.image) 
                        : AssetImage(service.image) as ImageProvider,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            // CONTENT BELOW
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      service.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.visible,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, height: 1.1),
                    ),
                    const SizedBox(height: 6),
                    if (service.isLocked)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(6)), 
                        child: Text(service.lockedLabel, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      )
                    else if (service.discountPercentage > 0)
                      Text("-${service.discountPercentage.toInt()}% OFF", style: const TextStyle(color: Colors.pinkAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceEditTile(ServiceModel service, int index) {
    return Container(
      key: ValueKey(service.id),
      margin: const EdgeInsets.only(bottom: 10),
      child: GlassContainer(
        opacity: 0.1,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          leading: Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              image: DecorationImage(
                image: service.image.startsWith('http') 
                    ? NetworkImage(service.image) 
                    : AssetImage(service.image) as ImageProvider,
                fit: BoxFit.cover,
              ),
            ),
          ),
          title: Text(service.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text(service.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => _deleteService(service),
              ),
              const Icon(Icons.drag_handle, color: Colors.white24),
            ],
          ),
        ),
      ),
    );
  }

}
