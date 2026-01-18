import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/branch_provider.dart';
import '../../../services/chat_service.dart';
import '../../../theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class AdminChatScreen extends StatefulWidget {
  const AdminChatScreen({super.key});

  @override
  State<AdminChatScreen> createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends State<AdminChatScreen> {
  String _filterStatus = 'All'; // All, Open, Closed
  String? _selectedChatId;
  final TextEditingController _msgController = TextEditingController();
  Timer? _inboxTimer;

  @override
  void initState() {
    super.initState();
    _startInboxPolling();
  }

  @override
  void dispose() {
    _inboxTimer?.cancel();
    _msgController.dispose();
    super.dispose();
  }

  void _startInboxPolling() {
    _fetchInbox();
    _inboxTimer?.cancel();
    _inboxTimer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchInbox());
  }

  void _fetchInbox() {
    final branchProvider = Provider.of<BranchProvider>(context, listen: false);
    if (branchProvider.selectedBranch != null) {
      Provider.of<ChatService>(context, listen: false).fetchThreads(
        branchProvider.selectedBranch!.id, 
        _filterStatus
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 800;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text("Admin Support Chat", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          _buildBranchSelector(),
          const SizedBox(width: 10),
        ],
      ),
      body: Consumer<ChatService>(
        builder: (context, chatService, _) {
          return Row(
            children: [
              // Left Panel: Chat List
              SizedBox(
                width: isLargeScreen ? 350 : screenWidth * 0.4,
                child: _buildChatList(isDark, chatService),
              ),
              // Divider
              VerticalDivider(width: 1, color: isDark ? Colors.white10 : Colors.black12),
              // Right Panel: Chat View
              Expanded(
                child: _selectedChatId == null
                    ? _buildEmptyState(isDark)
                    : _buildChatView(isDark, chatService),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildBranchSelector() {
    return Consumer<BranchProvider>(
      builder: (context, provider, _) {
        if (provider.selectedBranch == null && provider.branches.isNotEmpty) {
           // Auto-select first if none (for admin)
           // This shouldn't normally happen if they came from dashboard
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: provider.selectedBranch?.name,
              items: provider.branches
                  .map((b) => DropdownMenuItem(value: b.name, child: Text(b.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))))
                  .toList(),
              onChanged: (val) {
                 final branch = provider.branches.firstWhere((b) => b.name == val);
                 provider.selectBranch(branch);
                 _fetchInbox(); // Refresh on branch change
              },
              icon: const Icon(Icons.arrow_drop_down, size: 18),
            ),
          ),
        );
      }
    );
  }

  Widget _buildChatList(bool isDark, ChatService chatService) {
    final threads = chatService.threads;

    return Column(
      children: [
        // Filters
        Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['All', 'Open', 'Closed'].map((s) {
              final isSelected = _filterStatus == s;
              return GestureDetector(
                onTap: () {
                  setState(() => _filterStatus = s);
                  _fetchInbox();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: isSelected ? AppTheme.primaryColor : (isDark ? Colors.white24 : Colors.black12)),
                  ),
                  child: Text(s, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black54), fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: threads.isEmpty 
            ? Center(child: Text("No chats found", style: TextStyle(color: isDark ? Colors.white24 : Colors.black26)))
            : ListView.builder(
                itemCount: threads.length,
                itemBuilder: (context, index) {
                  final thread = threads[index];
                  final isSelected = _selectedChatId == thread['_id'];
                  final lastTime = DateTime.parse(thread['lastMessageAt']);
                  final timeStr = DateFormat('h:mm a').format(lastTime.toLocal());
                  final userName = thread['userId'] != null ? thread['userId']['name'] : "Unknown User";

                  return ListTile(
                    selected: isSelected,
                    selectedTileColor: AppTheme.primaryColor.withOpacity(0.1),
                    onTap: () {
                      setState(() => _selectedChatId = thread['_id']);
                      chatService.selectThread(thread['_id']);
                    },
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                      child: Text(userName[0], style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
                        Text(timeStr, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                    subtitle: Row(
                      children: [
                        Expanded(child: Text(thread['lastMessageText'] ?? "No messages", style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54), overflow: TextOverflow.ellipsis)),
                        if (thread['unreadCountAdmin'] > 0)
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                            child: Text(thread['unreadCountAdmin'].toString(), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }

  Widget _buildChatView(bool isDark, ChatService chatService) {
    if (chatService.currentThread == null) return const Center(child: CircularProgressIndicator());
    final thread = chatService.currentThread!;
    final userName = thread['userId'] != null ? thread['userId']['name'] : "User";

    return Column(
      children: [
        // Chat Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(thread['status'].toString().toUpperCase(), style: TextStyle(fontSize: 10, color: thread['status'] == 'open' ? Colors.green : Colors.grey)),
                ],
              ),
              const Spacer(),
              _buildActionChip(Icons.person_outline, "Profile", () {}),
              const SizedBox(width: 8),
              _buildActionChip(
                thread['status'] == 'open' ? Icons.check_circle_outline : Icons.replay,
                thread['status'] == 'open' ? "Close" : "Reopen",
                () {
                  final newStatus = thread['status'] == 'open' ? 'closed' : 'open';
                  chatService.updateThreadStatus(thread['_id'], newStatus);
                },
              ),
            ],
          ),
        ),
        // Messages
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: chatService.messages.length,
            itemBuilder: (context, index) {
               final msg = chatService.messages[index];
               final isAdmin = msg['senderType'] == 'admin';
               final createdAt = DateTime.parse(msg['createdAt']);
               return _buildMessageBubble(msg['messageText'], createdAt.toLocal(), isAdmin, isDark);
            },
          ),
        ),
        // Input
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _msgController,
                  decoration: InputDecoration(
                    hintText: "Type a message...",
                    hintStyle: const TextStyle(fontSize: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20), 
                  onPressed: () {
                    final text = _msgController.text.trim();
                    if (text.isNotEmpty) {
                      chatService.sendMessage(text);
                      _msgController.clear();
                    }
                  }
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: isDark ? Colors.white10 : Colors.black12),
          const SizedBox(height: 20),
          Text("Select a chat to start messaging", style: TextStyle(color: isDark ? Colors.white38 : Colors.black38)),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, DateTime time, bool isAdmin, bool isDark) {
    return Align(
      alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isAdmin ? AppTheme.primaryColor : (isDark ? Colors.white10 : Colors.grey[200]),
          borderRadius: BorderRadius.circular(15).copyWith(
            bottomRight: isAdmin ? Radius.zero : const Radius.circular(15),
            bottomLeft: isAdmin ? const Radius.circular(15) : Radius.zero,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text, style: TextStyle(color: isAdmin ? Colors.white : (isDark ? Colors.white : Colors.black87), fontSize: 13)),
            const SizedBox(height: 4),
            Text(DateFormat('h:mm a').format(time), style: TextStyle(color: isAdmin ? Colors.white60 : Colors.grey, fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionChip(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: AppTheme.primaryColor),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
