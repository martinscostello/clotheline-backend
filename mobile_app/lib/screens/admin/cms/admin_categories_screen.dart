import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../services/store_service.dart';
import '../../../../providers/branch_provider.dart';
import '../../../../widgets/glass/GlassContainer.dart';
import '../../../../widgets/glass/LiquidBackground.dart';
import '../../../../theme/app_theme.dart';
import '../../../../models/category_model.dart';
import '../../../../utils/toast_utils.dart';
class AdminCategoriesScreen extends StatelessWidget {
  const AdminCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text("Manage Categories", style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.transparent,
          leading: const BackButton(color: Colors.white),
        ),
        body: const LiquidBackground(
          child: AdminCategoriesBody(),
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

  Future<void> _onBranchChanged(String? newId) async {
    if (newId == null) return;
    
    setState(() => _isLoading = true);
    final branchProvider = Provider.of<BranchProvider>(context, listen: false);
    
    final branch = branchProvider.branches.firstWhere((b) => b.id == newId);
    branchProvider.selectBranch(branch);
    
    await _storeService.fetchCategories(branchId: newId);
    if (mounted) setState(() => _isLoading = false);
  }

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

        if (!widget.isEmbedded)
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            right: 20,
            child: Consumer<BranchProvider>(
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
          ),
      ],
    );
  }
}
