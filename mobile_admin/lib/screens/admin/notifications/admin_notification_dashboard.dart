import 'package:flutter/material.dart';
import 'package:dio/dio.dart'; 
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_admin/widgets/glass/GlassContainer.dart';
import '../../../widgets/glass/LiquidBackground.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart'; 
import 'package:clotheline_core/clotheline_core.dart';
import 'package:provider/provider.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart'; 
import '../orders/admin_order_detail_screen.dart';
import '../chat/admin_chat_screen.dart';

class AdminNotificationDashboard extends StatefulWidget {
  const AdminNotificationDashboard({super.key});

  @override
  State<AdminNotificationDashboard> createState() => _AdminNotificationDashboardState();
}

class _AdminNotificationDashboardState extends State<AdminNotificationDashboard> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
       final ns = Provider.of<NotificationService>(context, listen: false);
       ns.fetchNotifications();
       ns.markAllAsRead(); // [Auto-Read Policy]
    });
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
        ),
        body: LiquidBackground(
          child: _buildInboxTab(),
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
            padding: const EdgeInsets.only(top: 100, left: 20, right: 20, bottom: 20),
            itemCount: ns.notifications.length,
            itemBuilder: (context, index) {
              final n = ns.notifications[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () {
                    final meta = n['metadata'];
                    if (n['type'] == 'order' && meta != null && meta['orderId'] != null) {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => AdminOrderDetailScreen(orderId: meta['orderId'])
                      ));
                    } else if (n['type'] == 'chat') {
                      final threadId = meta != null ? meta['threadId'] : null;
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
                            color: (n['isRead'] == true ? Colors.grey : AppTheme.primaryColor).withOpacity(0.2),
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
}
