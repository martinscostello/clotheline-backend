import 'package:flutter/material.dart';
import 'package:dio/dio.dart'; 
import 'package:laundry_app/theme/app_theme.dart';
import 'package:laundry_app/widgets/glass/GlassContainer.dart';
import '../../../widgets/glass/LiquidBackground.dart'; // [FIX] Import Admin Background
import 'package:laundry_app/services/api_service.dart';
import 'package:laundry_app/services/auth_service.dart'; 
import 'package:laundry_app/utils/toast_utils.dart';
import 'package:provider/provider.dart';
import '../../../services/notification_service.dart';
import '../../../services/push_notification_service.dart'; 
import '../orders/admin_order_detail_screen.dart';
import '../chat/admin_chat_screen.dart';

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
    Future.microtask(() {
       final ns = Provider.of<NotificationService>(context, listen: false);
       ns.fetchNotifications();
       ns.markAllAsRead(); // [Auto-Read Policy]
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _forceSyncToken() async {
      setState(() => _isLoading = true);
      try {
         // 1. Check if we can get a token from Firebase SDK directly
         String? token = await PushNotificationService.getToken();
         
         if (token == null) {
            ToastUtils.show(context, "Error: Firebase returned NO Token. Check Google Services config.", type: ToastType.error);
            return;
         }

         // 2. We have a token, try to send it
         // Use AuthService to send, but we trust it works if token exists
         await Provider.of<AuthService>(context, listen: false).syncFcmToken();
         
         if (mounted) {
            ToastUtils.show(context, "Token Acquired & Synced! \nRef: ${token.substring(0, 5)}...", type: ToastType.success);
         }
      } catch (e) {
         ToastUtils.show(context, "Sync Exception: $e", type: ToastType.error);
      } finally {
         setState(() => _isLoading = false);
      }
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

  Future<void> _testNotificationSettings() async {
    setState(() => _isLoading = true);
    try {
      final api = ApiService();
      // Call Diagnostic Endpoint
      final response = await api.client.post('/notifications/test');
      
      if (mounted) {
        // Show Detailed Result
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E2C),
            title: const Text("Diagnostic Result", style: TextStyle(color: Colors.white)),
            content:  Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text("Status: ${response.statusCode}", style: const TextStyle(color: Colors.white70)),
                 const SizedBox(height: 10),
                 Text("Response:", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                 const SizedBox(height: 5),
                 Container(
                   padding: const EdgeInsets.all(10),
                   decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                   child: Text(response.data.toString(), style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontFamily: 'Courier')),
                 ),
                 const SizedBox(height: 20),
                 const Text("If 'tokenCount' > 0 and no error, check your phone's notification settings.", style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close"))
            ],
          )
        );
      }
    } on DioException catch (e) {
      if (mounted) {
         bool isNoToken = e.response?.statusCode == 400;
         
         showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E2C),
            title: Text(isNoToken ? "Device Not Registered" : "Test Failed", style: const TextStyle(color: Colors.redAccent)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isNoToken 
                   ? "This device has not sent its Push Token to the server yet."
                   : "Error: ${e.response?.data['msg'] ?? e.message}", 
                  style: const TextStyle(color: Colors.white70)
                ),
                if (isNoToken)
                  Padding(
                    padding: const EdgeInsets.only(top: 15),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                      icon: const Icon(Icons.sync, color: Colors.white),
                      label: const Text("Fix Connection Now", style: TextStyle(color: Colors.white)),
                      onPressed: () async {
                         Navigator.pop(ctx);
                         _forceSyncToken();
                      },
                    ),
                  )
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close"))
            ],
          )
        );
      }
    } catch (e) {
       // ... existing generic catch ...
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text("Notifications", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          // Actions removed (Debug button)
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.primaryColor,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            tabs: const [
              Tab(text: "Inbox"),
              Tab(text: "Compose"),
            ],
          ),
        ),
        // [FIX] Use LiquidBackground for Admin Dark UI
        body: LiquidBackground(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildInboxTab(),
              _buildComposeTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInboxTab() {
    return Consumer<NotificationService>(
      builder: (context, ns, _) {
        if (ns.isLoading) return const Center(child: CircularProgressIndicator());
        if (ns.notifications.isEmpty) return const Center(child: Text("No notifications", style: TextStyle(color: Colors.white54)));

        return RefreshIndicator(
          onRefresh: () => ns.fetchNotifications(),
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 140, left: 20, right: 20, bottom: 20), // Added top padding for header
            itemCount: ns.notifications.length,
            itemBuilder: (context, index) {
              final n = ns.notifications[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () {
                    // Deep Linking Logic
                    final meta = n['metadata'];
                    if (n['type'] == 'order' && meta != null && meta['orderId'] != null) {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => AdminOrderDetailScreen(orderId: meta['orderId'])
                      ));
                    } else if (n['type'] == 'chat') {
                      // Support both threadId and userId if needed, currently threadId
                      final threadId = meta != null ? meta['threadId'] : null;
                      // Fallback: If no threadId, just go to chat dashboard
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => AdminChatScreen(initialThreadId: threadId)
                      ));
                    }
                  },
                  child: GlassContainer(
                    opacity: n['isRead'] == true ? 0.05 : 0.15,
                    padding: const EdgeInsets.all(15),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (n['isRead'] == true ? Colors.grey : AppTheme.primaryColor).withValues(alpha: 0.2),
                            shape: BoxShape.circle
                          ),
                          child: Icon(
                            n['type'] == 'order' ? Icons.local_laundry_service : Icons.chat_bubble,
                            color: n['isRead'] == true ? Colors.white54 : AppTheme.primaryColor,
                            size: 20
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(n['title'] ?? "Notification", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(n['message'] ?? "", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      }
    );
  }

  Widget _buildComposeTab() {
    return SingleChildScrollView(
      // [FIX] padding top to clear Header + Tabs (approx 160)
      padding: const EdgeInsets.only(top: 160, left: 20, right: 20, bottom: 40),
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
                        DropdownMenuItem(value: 'all', child: Text(\"All Users\")),
                        DropdownMenuItem(value: 'benin', child: Text(\"Users in Benin\")),
                        DropdownMenuItem(value: 'abuja', child: Text(\"Users in Abuja\")),
                        DropdownMenuItem(value: 'active_orders', child: Text(\"Users with Active Orders\")),
                        DropdownMenuItem(value: 'cancelled_orders', child: Text(\"Users with Cancelled Orders\")),
                        DropdownMenuItem(value: 'zero_orders', child: Text(\"Users with Zero Orders\")),
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
      fillColor: Colors.white.withValues(alpha: 0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
    );
  }
}
