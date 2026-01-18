import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:laundry_app/theme/app_theme.dart';
import 'package:liquid_glass_ui/liquid_glass_ui.dart';
import 'package:laundry_app/widgets/glass/GlassContainer.dart';
import 'package:laundry_app/services/api_service.dart';
import 'package:laundry_app/utils/toast_utils.dart';
import 'package:laundry_app/widgets/toast/top_toast.dart';

class AdminNotificationDashboard extends StatefulWidget {
  const AdminNotificationDashboard({super.key});

  @override
  State<AdminNotificationDashboard> createState() => _AdminNotificationDashboardState();
}

class _AdminNotificationDashboardState extends State<AdminNotificationDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _targetAudience = 'all'; // all, active_orders
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Notifications", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: "Compose"),
            Tab(text: "History"),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F1115), Color(0xFF161A20)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter
          )
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildComposeTab(),
            _buildHistoryTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildComposeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Send Broadcast", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          const Text("Send a message to all users or specific groups.", style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 20),

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
                        DropdownMenuItem(value: 'active_orders', child: Text("Users with Active Orders")),
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
    );
  }

  Widget _buildHistoryTab() {
    return const Center(
      child: Text("History coming soon...", style: TextStyle(color: Colors.white54)),
    );
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
}
