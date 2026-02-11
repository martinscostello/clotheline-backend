import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/notification_service.dart';
import '../main_layout.dart'; 
import '../chat/chat_screen.dart';
import 'package:laundry_app/widgets/glass/LaundryGlassBackground.dart';
import 'package:laundry_app/widgets/glass/UnifiedGlassHeader.dart';
import '../../../theme/app_theme.dart';

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
                             Navigator.pushAndRemoveUntil(
                                context, 
                                MaterialPageRoute(builder: (_) => const MainLayout(initialIndex: 2)), 
                                (route) => false
                             );
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
                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                 title: Text(n['title'] ?? "Broadcast", style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
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
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isDark ? (isRead ? Colors.white.withOpacity(0.1) : AppTheme.primaryColor.withOpacity(0.3)) : Colors.black12,
                              width: isRead ? 1 : 1.5
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _getIconColor(n['type']).withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(_getIcon(n['type']), color: _getIconColor(n['type']), size: 24),
                              ),
                              const SizedBox(width: 16),
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
                                              fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                                              color: isDark ? Colors.white : Colors.black87,
                                              fontSize: 17
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          )
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _timeAgo(n['createdAt']),
                                          style: TextStyle(
                                             fontSize: 11, 
                                             color: isDark ? Colors.white38 : Colors.black38,
                                          )
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                       n['message'] ?? "", 
                                       style: TextStyle(
                                         color: isDark ? Colors.white70 : Colors.black54,
                                         fontSize: 14,
                                         height: 1.4,
                                       ),
                                       maxLines: 4,
                                       overflow: TextOverflow.ellipsis,
                                    ),
                                    if (!isRead) ...[
                                       const SizedBox(height: 10),
                                       Container(
                                         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                         decoration: BoxDecoration(
                                           color: AppTheme.primaryColor.withOpacity(0.2),
                                           borderRadius: BorderRadius.circular(10),
                                         ),
                                         child: const Text("NEW", style: TextStyle(color: AppTheme.primaryColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                       ),
                                    ]
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
