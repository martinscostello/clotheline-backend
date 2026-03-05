import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:clotheline_core/clotheline_core.dart';
import '../../../../widgets/glass/GlassContainer.dart';
import '../../../../widgets/glass/LiquidBackground.dart';
final GlobalKey<_AdminCategoriesBodyState> _bodyKey = GlobalKey<_AdminCategoriesBodyState>();

class AdminCategoriesScreen extends StatelessWidget {
  const AdminCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text("Manage Categories", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3), // Faded soft
              border: const Border(bottom: BorderSide(color: Colors.white10)),
            ),
          ),
          leading: const BackButton(color: Colors.white),
          actions: [
            Consumer<BranchProvider>(
              builder: (context, branchProvider, _) {
                if (branchProvider.branches.isEmpty) return const SizedBox.shrink();

                if (branchProvider.isLockedToSingleBranch) {
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(20)
                    ),
                    child: Text(branchProvider.branches.first.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  );
                }

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(20)
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      dropdownColor: const Color(0xFF202020),
                      value: branchProvider.selectedBranch?.id,
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                      onChanged: (val) {
                         if (val != null) {
                            final branch = branchProvider.branches.firstWhere((b) => b.id == val);
                            branchProvider.selectBranch(branch);
                            // Trigger Fetch
                            Provider.of<StoreService>(context, listen: false).fetchCategories(branchId: val);
                         }
                      },
                      items: branchProvider.branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name, style: const TextStyle(color: Colors.white, fontSize: 13)))).toList(),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 10),
            IconButton(
              icon: const Icon(Icons.sort_rounded, color: Colors.white),
              onPressed: () => _bodyKey.currentState?._showFilterOptions(),
            ),
            const SizedBox(width: 10),
          ],
        ),
        body: LiquidBackground(
          child: AdminCategoriesBody(key: _bodyKey),
        ),
      ),
    );
  }
}

class AdminCategoriesBody extends StatefulWidget {
  final bool isEmbedded;
  const AdminCategoriesBody({super.key, this.isEmbedded = false});

  @override
  State<AdminCategoriesBody> createState() => _AdminCategoriesBodyState();
}

class _AdminCategoriesBodyState extends State<AdminCategoriesBody> {
  final StoreService _storeService = StoreService();
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
    
    // Ensure branches are loaded
    if (branchProvider.branches.isEmpty) {
      await branchProvider.fetchBranches();
    }
    
    // Default to first branch if none selected
    if (branchProvider.selectedBranch == null && branchProvider.branches.isNotEmpty) {
       branchProvider.selectBranch(branchProvider.branches.first);
    }

    final branchId = branchProvider.selectedBranch?.id;
    await _storeService.fetchCategories(branchId: branchId);
    if (mounted) setState(() => _isLoading = false);
  }

  // _onBranchChanged removed

  void _showAddDialog() {
    final TextEditingController nameCtrl = TextEditingController();
    final branchProvider = Provider.of<BranchProvider>(context, listen: false);
    final branchId = branchProvider.selectedBranch?.id;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF202020),
        title: Text("Add Category (${branchProvider.selectedBranch?.name ?? 'Global'})", style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: "Category Name",
            labelStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24))
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty) {
                 Navigator.pop(ctx);
                 setState(() => _isLoading = true);
                 final error = await _storeService.addCategory(nameCtrl.text, branchId: branchId);
                 setState(() => _isLoading = false);
                 
                 if (error != null && mounted) {
                    ToastUtils.show(context, "Failed: $error", type: ToastType.error);
                 }
              }
            },
            child: const Text("Add"),
          )
        ],
      )
    );
  }

  void _showDeleteDialog(CategoryModel category) {
     final branchProvider = Provider.of<BranchProvider>(context, listen: false);
     final branchId = branchProvider.selectedBranch?.id;

     showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF202020),
        title: const Text("Delete Category?", style: TextStyle(color: Colors.white)),
        content: Text("Are you sure you want to delete '${category.name}'?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
               Navigator.pop(ctx);
               setState(() => _isLoading = true);
               await _storeService.deleteCategory(category.id, branchId: branchId);
               setState(() => _isLoading = false);
            },
            child: const Text("Delete"),
          )
        ],
      )
    );
  }

  void _showFilterOptions() {
    final branchProvider = Provider.of<BranchProvider>(context, listen: false);
    final currentSort = branchProvider.selectedBranch?.categorySortOrder ?? 'alphabetical';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Filter Categories By", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            _buildSortTile("Alphabetically A-Z", "alphabetical", currentSort, Icons.sort_by_alpha),
            _buildSortTile("Newest - Oldest", "newest", currentSort, Icons.history),
            _buildSortTile("Oldest - Newest", "oldest", currentSort, Icons.update),
          ],
        ),
      ),
    );
  }

  Widget _buildSortTile(String title, String value, String current, IconData icon) {
    final isSelected = value == current;
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppTheme.primaryColor : Colors.white54),
      title: Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      trailing: isSelected ? const Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 20) : null,
      onTap: () {
        Navigator.pop(context);
        if (!isSelected) {
          _updateSortOrder(value);
        }
      },
    );
  }

  Future<void> _updateSortOrder(String newOrder) async {
    final branchProvider = Provider.of<BranchProvider>(context, listen: false);
    final branchId = branchProvider.selectedBranch?.id;
    if (branchId == null) return;

    setState(() => _isLoading = true);
    
    try {
      final api = ApiService();
      final response = await api.client.put('/branches/$branchId', data: {
        'categorySortOrder': newOrder,
      });

      if (response.statusCode == 200) {
        // Update local state by re-fetching branch or just updating provider
        await branchProvider.fetchBranches();
        // Refresh categories
        await _loadData();
        ToastUtils.show(context, "Sort order updated", type: ToastType.success);
      }
    } catch (e) {
      ToastUtils.show(context, "Update failed: $e", type: ToastType.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_isLoading)
          const Center(child: CircularProgressIndicator(color: Colors.white))
        else
          ListenableBuilder(
            listenable: _storeService,
            builder: (context, _) {
              final categories = _storeService.categoryObjects;
              if (categories.isEmpty) {
                return const Center(child: Text("No categories found", style: TextStyle(color: Colors.white54)));
              }

              return ListView.separated(
                padding: EdgeInsets.fromLTRB(20, widget.isEmbedded ? 20 : 100, 20, 100),
                itemCount: categories.length,
                separatorBuilder: (_,__) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  return GlassContainer(
                    opacity: 0.1,
                    child: ListTile(
                      title: Text(cat.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.white30),
                        onPressed: () => _showDeleteDialog(cat),
                      ),
                    ),
                  );
                },
              );
            }
          ),
        
        Positioned(
          bottom: 20,
          right: 20,
          child: FloatingActionButton(
            onPressed: _showAddDialog,
            backgroundColor: AppTheme.primaryColor,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),

      ],
    );
  }
}
