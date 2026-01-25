import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/notification_service.dart';
import 'package:liquid_glass_ui/liquid_glass_ui.dart';
import '../main_layout.dart'; 
import '../chat/chat_screen.dart';
import 'package:laundry_app/widgets/glass/LaundryGlassBackground.dart';
import 'package:laundry_app/widgets/glass/UnifiedGlassHeader.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final service = Provider.of<NotificationService>(context, listen: false);
      service.fetchNotifications();
      service.markAllAsRead(); // [Auto-Read Policy]
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: LaundryGlassBackground(
        child: Stack(
          children: [
            // 1. Content
            Consumer<NotificationService>(
              builder: (context, notifService, _) {
                if (notifService.isLoading && notifService.notifications.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (notifService.notifications.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined, size: 60, color: isDark ? Colors.white24 : Colors.grey[300]),
                        const SizedBox(height: 10),
                        Text("No notifications yet", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => notifService.fetchNotifications(),
                  color: isDark ? Colors.white : Colors.black87,
                  child: ListView.separated(
                    padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 130, bottom: 40, left: 16, right: 16),
                    itemCount: notifService.notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final n = notifService.notifications[index];
                      final isRead = n['isRead'] == true;
                      
                      return GestureDetector(
                        onTap: () {
                          if (!isRead) {
                             Provider.of<NotificationService>(context, listen: false).markAsRead(n['_id']);
                          }

                          if (n['type'] == 'order') {
                             if (n['metadata'] != null && n['metadata']['orderId'] != null) {
                                // Navigate to specific order
                                // We need to handle this via a route or direct push
                                // Assuming OrderDetailScreen exists and takes an ID or Model
                                // For now, let's go to Orders Tab but we should ideally open the detail.
                                // Let's check if we can push OrderDetailScreen.
                                // We need to fetch the order first? 
                                // Better: Go to MainLayout index 1 (Orders) BUT pass an argument? 
                                // Simplest robust fix: Go to Orders tab.
                                // IMPROVEMENT: Check if we have orderId and push detail.
                                
                                // If we have the screen:
                                // import '../../orders/order_detail_screen.dart'; (Need to verify path)
                                
                                Navigator.pushAndRemoveUntil(
                                   context, 
                                   MaterialPageRoute(builder: (_) => const MainLayout(initialIndex: 1)), 
                                   (route) => false
                                );
                             } else {
                                Navigator.pushAndRemoveUntil(
                                   context, 
                                   MaterialPageRoute(builder: (_) => const MainLayout(initialIndex: 1)), 
                                   (route) => false
                                );
                             }
                          } else if (n['type'] == 'chat') {
                             Navigator.push(
                               context, 
                               MaterialPageRoute(builder: (_) => const ChatScreen())
                             );
                          } else if (n['type'] == 'broadcast') {
                             showDialog(
                               context: context, 
                               builder: (_) => AlertDialog(
                                 backgroundColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                                 title: Text(n['title'] ?? "Broadcast", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                                 content: Text(n['message'] ?? "", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                                 actions: [
                                   TextButton(
                                     onPressed: () => Navigator.pop(context), 
                                     child: const Text("Close")
                                   )
                                 ],
                               )
                             );
                          }
                        },
                        child: isDark 
                          ? Container(
                            // Telegram-style Dark Mode
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: const BoxDecoration(
                                border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5))
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Icon
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: _getIconColor(n['type']).withOpacity(0.1),
                                      shape: BoxShape.circle
                                    ),
                                    child: Icon(_getIcon(n['type']), color: _getIconColor(n['type']), size: 20),
                                  ),
                                  const SizedBox(width: 15),
                                  // Content
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(n['title'] ?? "Notification", 
                                                style: TextStyle(
                                                  fontWeight: isRead ? FontWeight.normal : FontWeight.w600, // Slightly less bold for cleanest read
                                                  color: Colors.white,
                                                  fontSize: 16
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              )
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _timeAgo(n['createdAt']),
                                              style: TextStyle(
                                                 fontSize: 12, 
                                                 color: Colors.white38,
                                                 fontWeight: isRead ? FontWeight.normal : FontWeight.w500
                                              )
                                            ),
                                            if (!isRead) ...[
                                               const SizedBox(width: 8),
                                               Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle))
                                            ]
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                           n['message'] ?? "", 
                                           style: TextStyle(
                                             color: isRead ? Colors.white54 : Colors.white70,
                                             fontWeight: isRead ? FontWeight.normal : FontWeight.normal
                                           ),
                                           maxLines: 2,
                                           overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                          )
                          : LiquidGlassContainer(
                            padding: const EdgeInsets.all(16),
                            opacity: isRead ? 0.05 : 0.15, // Higher opacity for unread
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Icon
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: _getIconColor(n['type']).withOpacity(0.1),
                                    shape: BoxShape.circle
                                  ),
                                  child: Icon(_getIcon(n['type']), color: _getIconColor(n['type']), size: 20),
                                ),
                                const SizedBox(width: 15),
                                // Content
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(n['title'] ?? "Notification", 
                                              style: TextStyle(
                                                fontWeight: isRead ? FontWeight.normal : FontWeight.w800, // Bold for unread
                                                color: isDark ? Colors.white : Colors.black87,
                                                fontSize: 16
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            )
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _timeAgo(n['createdAt']),
                                            style: TextStyle(
                                               fontSize: 12, 
                                               color: isDark ? Colors.white38 : Colors.black38,
                                               fontWeight: isRead ? FontWeight.normal : FontWeight.bold
                                            )
                                          ),
                                          if (!isRead) ...[
                                             const SizedBox(width: 6),
                                             Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle))
                                          ]
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                         n['message'] ?? "", 
                                         style: TextStyle(
                                           color: isDark ? Colors.white70 : Colors.black54,
                                           fontWeight: isRead ? FontWeight.normal : FontWeight.w500
                                         ),
                                         maxLines: 2,
                                         overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ),
                      );
                    },
                  ),
                );
              },
            ),

            // 2. Header
            Positioned(
              top: 0, left: 0, right: 0,
              child: UnifiedGlassHeader(
                isDark: isDark,
                title: Text("Notifications", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.done_all, size: 24),
                    onPressed: () {
                      Provider.of<NotificationService>(context, listen: false).markAllAsRead();
                    },
                  )
                ],
                onBack: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return "";
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date);
      if (diff.inDays > 0) return "${diff.inDays}d ago";
      if (diff.inHours > 0) return "${diff.inHours}h ago";
      if (diff.inMinutes > 0) return "${diff.inMinutes}m ago";
      return "Just now";
    } catch (_) {
      return "";
    }
  }

  IconData _getIcon(String? type) {
    switch (type) {
      case 'order': return Icons.local_shipping_outlined;
      case 'bucket': return Icons.cleaning_services_outlined;
      case 'broadcast': return Icons.campaign_outlined;
      case 'chat': return Icons.chat_bubble_outline;
      default: return Icons.notifications_none_outlined;
    }
  }

  Color _getIconColor(String? type) {
    switch (type) {
      case 'order': return Colors.blueAccent;
      case 'bucket': return Colors.orangeAccent;
      case 'broadcast': return Colors.purpleAccent;
      case 'chat': return Colors.greenAccent;
      default: return Colors.grey;
    }
  }
}
