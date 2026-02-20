import 'package:flutter/material.dart';
import 'package:laundry_app/models/app_content_model.dart';
import 'package:laundry_app/services/content_service.dart';
import 'package:laundry_app/services/api_service.dart';
import 'package:laundry_app/theme/app_theme.dart';
import 'package:laundry_app/utils/toast_utils.dart';
import '../../../widgets/glass/LiquidBackground.dart';

class AdminPromotionalTemplatesScreen extends StatefulWidget {
  const AdminPromotionalTemplatesScreen({super.key});

  @override
  State<AdminPromotionalTemplatesScreen> createState() => _AdminPromotionalTemplatesScreenState();
}

class _AdminPromotionalTemplatesScreenState extends State<AdminPromotionalTemplatesScreen> {
  bool _isLoading = true;
  AppContentModel? _content;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() => _isLoading = true);
    try {
      final content = await ContentService().getAppContent();
      if (mounted) {
        setState(() {
          _content = content;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.show(context, "Failed to load templates", type: ToastType.error);
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveTemplates() async {
    if (_content == null) return;
    setState(() => _isLoading = true);
    try {
      final api = ApiService();
      await api.client.put('/content', data: {
        'promotionalTemplates': _content!.promotionalTemplates.map((e) => e.toJson()).toList()
      });
      // Refresh cache
      await ContentService().refreshAppContent();
      if (mounted) {
        ToastUtils.show(context, "Templates saved successfully", type: ToastType.success);
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.show(context, "Failed to save: $e", type: ToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showTemplateEditor([PromotionalTemplate? template, int? index]) {
    final titleCtrl = TextEditingController(text: template?.title ?? '');
    final msgCtrl = TextEditingController(text: template?.message ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E2C),
          title: Text(template == null ? "Add Template" : "Edit Template", style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Title (e.g. Emoji included)",
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: msgCtrl,
                style: const TextStyle(color: Colors.white),
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: "Message",
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              )
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text("Cancel", style: TextStyle(color: Colors.white54))
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
              onPressed: () {
                if (titleCtrl.text.isEmpty || msgCtrl.text.isEmpty) {
                  ToastUtils.show(context, "All fields are required", type: ToastType.info);
                  return;
                }
                
                setState(() {
                  final newTemplate = PromotionalTemplate(title: titleCtrl.text, message: msgCtrl.text);
                  if (template == null) {
                    _content!.promotionalTemplates.add(newTemplate);
                  } else {
                    _content!.promotionalTemplates[index!] = newTemplate;
                  }
                });
                Navigator.pop(context);
                _saveTemplates();
              }, 
              child: const Text("Save", style: TextStyle(color: Colors.white))
            )
          ],
        );
      }
    );
  }

  void _confirmDelete(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text("Delete Template?", style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure you want to delete this promotional template?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              setState(() {
                _content!.promotionalTemplates.removeAt(index);
              });
              Navigator.pop(context);
              _saveTemplates();
            }, 
            child: const Text("Delete", style: TextStyle(color: Colors.white))
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final templates = _content?.promotionalTemplates ?? [];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Edit Templates", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.add, color: AppTheme.primaryColor),
              onPressed: () => _showTemplateEditor(),
              tooltip: "Add Template",
            )
        ],
      ),
      body: LiquidBackground(
        child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : templates.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.white24, size: 60),
                    const SizedBox(height: 15),
                    const Text("No templates found", style: TextStyle(color: Colors.white54, fontSize: 16)),
                    const SizedBox(height: 15),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add, color: Colors.white, size: 18),
                      label: const Text("Add Template", style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                      onPressed: () => _showTemplateEditor(),
                    )
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.only(top: 100, bottom: 40, left: 15, right: 15),
                itemCount: templates.length,
                itemBuilder: (context, index) {
                  final t = templates[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                      title: Text(t.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(t.message, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3)),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white54, size: 20),
                            onPressed: () => _showTemplateEditor(t, index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                            onPressed: () => _confirmDelete(index),
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
