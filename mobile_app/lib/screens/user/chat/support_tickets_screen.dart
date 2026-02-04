import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:laundry_app/theme/app_theme.dart';
import 'package:laundry_app/widgets/glass/LaundryGlassBackground.dart';
import 'package:laundry_app/widgets/glass/UnifiedGlassHeader.dart';
import 'package:laundry_app/widgets/glass/LaundryGlassCard.dart';
import '../../../services/chat_service.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';

class SupportTicketsScreen extends StatefulWidget {
  const SupportTicketsScreen({super.key});

  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatService>().fetchMyThreads();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: LaundryGlassBackground(
        child: Stack(
          children: [
            Column(
              children: [
                const SizedBox(height: 120),
                Expanded(
                  child: Consumer<ChatService>(
                    builder: (context, chat, _) {
                      if (chat.isLoading && chat.myThreads.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (chat.myThreads.isEmpty) {
                        return _buildEmptyState(isDark);
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: chat.myThreads.length,
                        itemBuilder: (context, index) {
                          final thread = chat.myThreads[index];
                          return _buildThreadTile(thread, isDark, textColor);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
            Positioned(
              top: 0, left: 0, right: 0,
              child: UnifiedGlassHeader(
                isDark: isDark,
                title: Text("Support Tickets", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                onBack: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forum_outlined, size: 64, color: isDark ? Colors.white24 : Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("No support history found.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildThreadTile(Map<String, dynamic> thread, bool isDark, Color textColor) {
    final lastMsg = thread['lastMessageText'] ?? "No messages yet";
    final lastTime = DateTime.parse(thread['lastMessageAt'] ?? thread['createdAt']);
    final timeStr = DateFormat('MMM d, HH:mm').format(lastTime);
    final status = thread['status'] ?? 'open';
    final branchName = thread['branchId']?['name'] ?? "Support Thread";
    
    final isResolved = status == 'resolved';
    final unreadCount = thread['unreadCountUser'] ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
           // Navigate to ChatScreen with specific branch/thread context
           // We might need to adjust ChatScreen to handle branch selection
           Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(branchId: thread['branchId']?['_id'])));
        },
        child: LaundryGlassCard(
          opacity: isDark ? 0.12 : 0.15,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(branchName, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(width: 8),
                        _buildStatusBadge(status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lastMsg,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(timeStr, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    if (isResolved)
                       Padding(
                         padding: const EdgeInsets.only(top: 8),
                         child: Row(
                           children: [
                             const Icon(Icons.timer_outlined, size: 12, color: Colors.orangeAccent),
                             const SizedBox(width: 4),
                             const Text(
                               "Will be deleted in 3 days",
                               style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold),
                             ),
                           ],
                         ),
                       ),
                  ],
                ),
              ),
              if (unreadCount > 0)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                  child: Text("$unreadCount", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final isResolved = status == 'resolved';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isResolved ? Colors.green.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: isResolved ? Colors.green : Colors.blue,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
