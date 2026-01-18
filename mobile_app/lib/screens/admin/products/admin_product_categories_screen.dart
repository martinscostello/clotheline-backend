import 'package:flutter/material.dart';
import 'package:laundry_app/models/app_content_model.dart';
import 'package:laundry_app/services/content_service.dart';
import 'package:laundry_app/theme/app_theme.dart';
import 'package:laundry_app/widgets/glass/GlassContainer.dart';
import 'package:laundry_app/widgets/glass/LiquidBackground.dart';
import '../../../../utils/toast_utils.dart';
import '../../../../widgets/toast/top_toast.dart';

class AdminProductCategoriesScreen extends StatefulWidget {
  const AdminProductCategoriesScreen({super.key});

  @override
  State<AdminProductCategoriesScreen> createState() => _AdminProductCategoriesScreenState();
}

class _AdminProductCategoriesScreenState extends State<AdminProductCategoriesScreen> {
  final ContentService _contentService = ContentService();
  AppContentModel? _content;
  bool _isLoading = true;
  final TextEditingController _addController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchContent();
  }

  Future<void> _fetchContent() async {
    final content = await _contentService.getAppContent();
    if(mounted) {
      setState(() {
        _content = content;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveCategories() async {
    if (_content == null) return;
    final success = await _contentService.updateAppContent(_content!.toJson());
    if (success && mounted) {
      ToastUtils.show(context, "Categories Saved", type: ToastType.success);
    }
  }

  void _addCategory() {
    if (_addController.text.isNotEmpty && _content != null) {
      setState(() {
        _content!.productCategories.add(_addController.text);
        _addController.clear();
      });
      _saveCategories();
    }
  }

  void _removeCategory(String cat) {
    setState(() {
      _content!.productCategories.remove(cat);
    });
    _saveCategories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Product Categories", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: LiquidBackground(
        child: _isLoading 
            ? const Center(child: CircularProgressIndicator()) 
            : Padding(
              padding: const EdgeInsets.fromLTRB(20, 100, 20, 20),
              child: Column(
                children: [
                   GlassContainer(
                     opacity: 0.1,
                     child: Padding(
                       padding: const EdgeInsets.all(16.0),
                       child: Row(
                         children: [
                           Expanded(
                             child: TextField(
                               controller: _addController,
                               style: const TextStyle(color: Colors.white),
                               decoration: const InputDecoration(
                                 hintText: "New Category Name",
                                 hintStyle: TextStyle(color: Colors.white54),
                                 border: InputBorder.none
                               ),
                             ),
                           ),
                           IconButton(
                             icon: const Icon(Icons.add_circle, color: AppTheme.secondaryColor),
                             onPressed: _addCategory,
                           )
                         ],
                       ),
                     ),
                   ),
                   const SizedBox(height: 20),
                   Expanded(
                     child: ListView.builder(
                       itemCount: _content?.productCategories.length ?? 0,
                       itemBuilder: (ctx, i) {
                         final cat = _content!.productCategories[i];
                         return Padding(
                           padding: const EdgeInsets.only(bottom: 10),
                           child: GlassContainer(
                             opacity: 0.1,
                             child: ListTile(
                               title: Text(cat, style: const TextStyle(color: Colors.white)),
                               trailing: IconButton(
                                 icon: const Icon(Icons.delete, color: Colors.redAccent),
                                 onPressed: () => _removeCategory(cat),
                               ),
                             ),
                           ),
                         );
                       },
                     ),
                   )
                ],
              ),
            ),
      ),
    );
  }
}
