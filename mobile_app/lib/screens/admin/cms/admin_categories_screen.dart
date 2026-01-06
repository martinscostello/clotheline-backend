import 'package:flutter/material.dart';
import '../../../../services/store_service.dart';
import '../../../../widgets/glass/GlassContainer.dart';
import '../../../../widgets/glass/LiquidBackground.dart';
import '../../../../theme/app_theme.dart';
import '../../../../models/category_model.dart';

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  final StoreService _storeService = StoreService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _storeService.fetchCategories();
    setState(() => _isLoading = false);
  }

  void _showAddDialog() {
    final TextEditingController nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF202020),
        title: const Text("Add Category", style: TextStyle(color: Colors.white)),
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
                 final success = await _storeService.addCategory(nameCtrl.text);
                 setState(() => _isLoading = false);
                 
                 if (!success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to add category. Name might be duplicate.")));
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
               await _storeService.deleteCategory(category.id);
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
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Manage Categories", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        leading: const BackButton(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: LiquidBackground(
        child: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.white))
        : ListenableBuilder(
          listenable: _storeService,
          builder: (context, _) {
            final categories = _storeService.categoryObjects;
            if (categories.isEmpty) {
              return const Center(child: Text("No categories found", style: TextStyle(color: Colors.white54)));
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 100, 20, 100),
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
      ),
    );
  }
}
