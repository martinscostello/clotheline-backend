import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/branch_provider.dart';
import '../../../services/chat_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass/LiquidBackground.dart'; // [FIX] Import Admin Background
import 'package:intl/intl.dart';
import 'dart:async';

class AdminChatScreen extends StatefulWidget {
  final String? initialThreadId;
  const AdminChatScreen({super.key, this.initialThreadId});

  @override
  State<AdminChatScreen> createState() => _AdminChatScreenState();
}
class _AdminChatScreenState extends State<AdminChatScreen> {
  String _filterStatus = 'All'; // All, Open, Closed
  String? _selectedChatId;
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _adminScrollController = ScrollController();
  Timer? _inboxTimer;
  bool _isAdminSending = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialThreadId != null) {
      _selectedChatId = widget.initialThreadId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
         Provider.of<ChatService>(context, listen: false).selectThread(widget.initialThreadId!);
      });
    }
    _startInboxPolling();
    _msgController.addListener(() {
      setState(() {}); // Rebuild for send button state
    });
  }

  void _scrollToBottom() {
    if (_adminScrollController.hasClients) {
      _adminScrollController.animateTo(
        _adminScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
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
    // [FIX] Force Dark Mode for Admin Chat to match Admin UI style
    const isDark = true; 
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 800;

    return Scaffold(
      backgroundColor: Colors.transparent, 
      extendBodyBehindAppBar: true, // [FIX] Extend background behind app bar
      resizeToAvoidBottomInset: false, 
      appBar: AppBar(
        title: const Text("Admin Support Chat", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          _buildBranchSelector(),
          const SizedBox(width: 10),
        ],
      ),
      // [FIX] Wrap with LiquidBackground (Admin Dark Theme)
      body: LiquidBackground(
        child: Padding( // [FIX] Added Padding to respect Header/Status Bar
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 60), 
          child: Consumer<ChatService>(
            builder: (context, chatService, _) {
              return Row(
                children: [
                  // Left Panel: Chat List
                  SizedBox(
                    width: isLargeScreen ? 350 : screenWidth * 0.4,
                    child: _buildChatList(isDark, chatService),
                  ),
                  // Divider
                  VerticalDivider(width: 1, color: Colors.white10),
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
        ),
      ),
    );
  }

  Widget _buildBranchSelector() {
    return Consumer<BranchProvider>(
      builder: (context, provider, _) {
        if (provider.selectedBranch == null && provider.branches.isNotEmpty) {
           // Auto-select first if none (for admin)
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: provider.selectedBranch?.name,
              dropdownColor: const Color(0xFF1E1E2C), // [FIX] Dark Dropdown
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold), // [FIX] White Text
              items: provider.branches
                  .map((b) => DropdownMenuItem(value: b.name, child: Text(b.name))) // Style inherited
                  .toList(),
              onChanged: (val) {
                 final branch = provider.branches.firstWhere((b) => b.name == val);
                 provider.selectBranch(branch);
                 _fetchInbox(); // Refresh on branch change
              },
              icon: const Icon(Icons.arrow_drop_down, size: 18, color: Colors.white70),
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
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
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
                    margin: const EdgeInsets.only(right: 8),
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
            controller: _adminScrollController,
            padding: const EdgeInsets.all(20),
            itemCount: chatService.messages.length,
            itemBuilder: (context, index) {
               final msg = chatService.messages[index];
               final isAdmin = msg['senderType'] == 'admin';
               final createdAt = DateTime.parse(msg['createdAt']);
               final orderId = msg['orderId'];
               return _buildMessageBubble(msg['messageText'], createdAt.toLocal(), isAdmin, isDark, orderId: orderId);
            },
          ),
        ),
        // Input
        Container(
          padding: EdgeInsets.only(
            top: 15,
            left: 15,
            right: 15,
            bottom: MediaQuery.of(context).viewInsets.bottom > 0 
                ? MediaQuery.of(context).viewInsets.bottom + 10 
                : MediaQuery.of(context).padding.bottom + 85 + 10,
          ),
          decoration: BoxDecoration(
            border: const Border(top: BorderSide(color: Colors.white10)),
            color: Colors.black.withOpacity(0.6), // Dark Glass background
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _msgController,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  style: const TextStyle(color: Colors.white), // White Text
                  decoration: InputDecoration(
                    hintText: "Type a reply...",
                    hintStyle: const TextStyle(fontSize: 14, color: Colors.white54),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1), // Glass Input
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: (_msgController.text.trim().isEmpty || _isAdminSending) 
                    ? null 
                    : () async {
                      final text = _msgController.text.trim();
                      setState(() => _isAdminSending = true);
                      await chatService.sendMessage(text);
                      if (mounted) {
                        _msgController.clear();
                        setState(() => _isAdminSending = false);
                        Future.delayed(const Duration(milliseconds: 100), () => _scrollToBottom());
                      }
                    },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: (_msgController.text.trim().isEmpty || _isAdminSending) 
                        ? Colors.grey.withOpacity(0.3) 
                        : AppTheme.primaryColor,
                    shape: BoxShape.circle
                  ),
                  child: Center(
                    child: _isAdminSending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  ),
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

  Widget _buildMessageBubble(String text, DateTime time, bool isAdmin, bool isDark, {String? orderId}) {
    return Align(
      alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isAdmin ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (orderId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3))
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shopping_bag_outlined, size: 10, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text("Order #${orderId.substring(orderId.length - 6).toUpperCase()}", 
                      style: const TextStyle(fontSize: 9, color: Colors.orange, fontWeight: FontWeight.bold)
                    ),
                  ],
                ),
              ),
            ),
          Container(
            margin: const EdgeInsets.only(bottom: 5),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
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
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
            child: Text(DateFormat('h:mm a').format(time), style: TextStyle(color: isDark ? Colors.white38 : Colors.grey, fontSize: 9)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.5)),
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
