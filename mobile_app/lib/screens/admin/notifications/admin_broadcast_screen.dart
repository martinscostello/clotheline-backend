import 'package:flutter/material.dart';
import 'package:dio/dio.dart'; 
import 'package:laundry_app/theme/app_theme.dart';
import 'package:laundry_app/widgets/glass/GlassContainer.dart';
import '../../../widgets/glass/LiquidBackground.dart';
import 'package:laundry_app/services/api_service.dart';
import 'package:laundry_app/services/content_service.dart';
import 'package:laundry_app/models/app_content_model.dart';
import 'package:laundry_app/utils/toast_utils.dart';
import 'package:laundry_app/screens/admin/notifications/admin_promotional_templates_screen.dart';

class AdminBroadcastScreen extends StatefulWidget {
  const AdminBroadcastScreen({super.key});

  @override
  State<AdminBroadcastScreen> createState() => _AdminBroadcastScreenState();
}

class _AdminBroadcastScreenState extends State<AdminBroadcastScreen> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _targetAudience = 'all'; // all, active_orders, etc
  bool _isLoading = false;
  AppContentModel? _content;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final content = await ContentService().getAppContent();
    if (mounted) {
      setState(() => _content = content);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendBroadcast() async {
    if (_titleController.text.isEmpty || _messageController.text.isEmpty) {
      ToastUtils.show(context, "Title and Message are required", type: ToastType.info);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final api = ApiService();
      await api.client.post('/broadcast', data: {
        'title': _titleController.text,
        'message': _messageController.text,
        'targetAudience': _targetAudience
      });

      if (mounted) {
        ToastUtils.show(context, "Broadcast Sent Successfully", type: ToastType.success);
        _titleController.clear();
        _messageController.clear();
        setState(() => _targetAudience = 'all');
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.show(context, "Failed to send: $e", type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
    );
  }

  Widget _buildPromotionalTemplates() {
    final templates = _content?.promotionalTemplates ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: const [
                Icon(Icons.auto_awesome, color: Colors.amber, size: 18),
                SizedBox(width: 8),
                Text("Promotional Templates", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            TextButton.icon(
              icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 14),
              label: const Text("Edit Templates", style: TextStyle(color: Colors.blueAccent, fontSize: 12)),
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPromotionalTemplatesScreen()));
                _loadTemplates();
              },
            )
          ],
        ),
        const SizedBox(height: 5),
        if (templates.isEmpty)
          const Padding(
             padding: EdgeInsets.symmetric(vertical: 20),
             child: Text("No templates available. Tap Edit to add.", style: TextStyle(color: Colors.white54, fontSize: 12)),
          )
        else
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final t = templates[index];
                return GestureDetector(
                  onTap: () {
                    _titleController.text = t.title;
                    _messageController.text = t.message;
                    setState(() => _targetAudience = 'all');
                    ToastUtils.show(context, "Template applied!", type: ToastType.success);
                  },
                  child: Container(
                    width: 240,
                    margin: const EdgeInsets.only(right: 15),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Text(t.message, style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.3), maxLines: 3, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text("Broadcast", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: LiquidBackground(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 120, left: 20, right: 20, bottom: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Send Broadcast", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                const Text("Send a message to all users or specific groups.", style: TextStyle(color: Colors.white54)),
                const SizedBox(height: 20),

                _buildPromotionalTemplates(),

                GlassContainer(
                  opacity: 0.1,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel("Title"),
                      TextField(
                        controller: _titleController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration("e.g. holiday Sale!"),
                      ),
                      const SizedBox(height: 20),
                      
                      _buildLabel("Message"),
                      TextField(
                        controller: _messageController,
                        maxLines: 4,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration("Enter your message here..."),
                      ),
                      const SizedBox(height: 20),

                      _buildLabel("Target Audience"),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white10)
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _targetAudience,
                            dropdownColor: const Color(0xFF1E1E2C),
                            isExpanded: true,
                            style: const TextStyle(color: Colors.white),
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text("All Users")),
                              DropdownMenuItem(value: 'benin', child: Text("Users in Benin")),
                              DropdownMenuItem(value: 'abuja', child: Text("Users in Abuja")),
                              DropdownMenuItem(value: 'active_orders', child: Text("Users with Active Orders")),
                              DropdownMenuItem(value: 'cancelled_orders', child: Text("Users with Cancelled Orders")),
                              DropdownMenuItem(value: 'zero_orders', child: Text("Users with Zero Orders")),
                            ],
                            onChanged: (val) => setState(() => _targetAudience = val!),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _sendBroadcast,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                          ),
                          child: _isLoading 
                            ? const CircularProgressIndicator(color: Colors.white) 
                            : const Text("SEND BROADCAST", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
