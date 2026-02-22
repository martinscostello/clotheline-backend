import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/branch_provider.dart';
import '../../../services/chat_service.dart';
import '../../../services/auth_service.dart';
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
  String? _selectedChatId; // Only relevant for Tablet/Desktop
  Timer? _inboxTimer;

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
  }

  @override
  void dispose() {
    _inboxTimer?.cancel();
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
    const isDark = true; // Force Admin Dark Mode

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth >= 600;

        return Scaffold(
          backgroundColor: Colors.transparent, 
          extendBodyBehindAppBar: true,
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
          body: LiquidBackground(
            child: Padding(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 60), 
              child: Consumer<ChatService>(
                builder: (context, chatService, _) {
                  // Sort threads: Recent first
                  final threads = List.from(chatService.threads);
                  threads.sort((a, b) {
                    final tA = DateTime.tryParse(a['lastMessageAt'] ?? '') ?? DateTime(2000);
                    final tB = DateTime.tryParse(b['lastMessageAt'] ?? '') ?? DateTime(2000);
                    return tB.compareTo(tA); // Descending
                  });

                  if (isLargeScreen) {
                    // Split View
                    return Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildChatList(threads, isDark, chatService, (id) {
                            setState(() => _selectedChatId = id);
                            chatService.selectThread(id);
                          }),
                        ),
                        const VerticalDivider(width: 1, color: Colors.white10),
                        Expanded(
                          flex: 7,
                          child: _selectedChatId == null
                              ? _buildEmptyState(isDark)
                              : AdminChatDetailView(key: ValueKey(_selectedChatId), threadId: _selectedChatId!),
                        ),
                      ],
                    );
                  } else {
                    // Mobile View (List Only)
                    return _buildChatList(threads, isDark, chatService, (id) {
                       // Push to Detail
                       chatService.selectThread(id);
                       Navigator.push(
                         context,
                         MaterialPageRoute(builder: (_) => AdminMobileChatDetailScreen(threadId: id))
                       ).then((_) {
                         _fetchInbox(); // Refresh on return
                       });
                    });
                  }
                }
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildBranchSelector() {
    return Consumer<BranchProvider>(
      builder: (context, provider, _) {
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
              dropdownColor: const Color(0xFF1E1E2C),
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              items: provider.branches
                  .map((b) => DropdownMenuItem(value: b.name, child: Text(b.name))) 
                  .toList(),
              onChanged: (val) {
                 final branch = provider.branches.firstWhere((b) => b.name == val);
                 provider.selectBranch(branch);
                 _fetchInbox();
              },
              icon: const Icon(Icons.arrow_drop_down, size: 18, color: Colors.white70),
            ),
          ),
        );
      }
    );
  }

  Widget _buildChatList(List<dynamic> threads, bool isDark, ChatService chatService, Function(String) onSelect) {
    return Column(
      children: [
        // Filters
        Padding(
          padding: const EdgeInsets.all(10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['All', 'Open', 'Resolved'].map((s) {
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
                padding: const EdgeInsets.only(bottom: 20),
                itemCount: threads.length,
                itemBuilder: (context, index) {
                  final thread = threads[index];
                  final isSelected = _selectedChatId == thread['_id']; // Only visual for Tablet
                  final lastTime = DateTime.tryParse(thread['lastMessageAt'] ?? '')?.toLocal() ?? DateTime.now();
                  final timeStr = DateFormat('h:mm a').format(lastTime);
                  final userName = thread['userId'] != null ? thread['userId']['name'] : "Unknown User";

                  return ListTile(
                    selected: isSelected,
                    selectedTileColor: AppTheme.primaryColor.withOpacity(0.05),
                    onTap: () => onSelect(thread['_id']),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                      child: Text(userName.isNotEmpty ? userName[0] : '?', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis)),
                            Text(timeStr, style: const TextStyle(fontSize: 9, color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            _buildStatusBadge(thread),
                            const Spacer(),
                            if (thread['unreadCountAdmin'] != null && thread['unreadCountAdmin'] > 0)
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                                child: Text(thread['unreadCountAdmin'].toString(), style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                              ),
                          ],
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

  void _confirmDeleteThread(BuildContext context, ChatService chatService, String threadId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text("Delete Chat?", style: TextStyle(color: Colors.white)),
        content: const Text("This will permanently remove this chat from your list. The user's history will not be affected.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              chatService.deleteThread(threadId);
              Navigator.pop(ctx);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(dynamic thread) {
    String status = (thread['status'] ?? 'open').toString().toUpperCase();
    Color color = Colors.orangeAccent;
    String label = status;

    if (status == 'RESOLVED') {
      color = Colors.green;
    } else if (status == 'PICKED_UP') {
      color = Colors.blue;
      label = "PICKED UP - ${thread['assignedToAdminName']?.split(' ')[0] ?? 'Admin'}";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withOpacity(0.4), width: 0.5)
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 7, fontWeight: FontWeight.bold)),
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
}

// Extracted Detail View (Used in Split & Mobile)
class AdminChatDetailView extends StatefulWidget {
  final String threadId;
  const AdminChatDetailView({super.key, required this.threadId});

  @override
  State<AdminChatDetailView> createState() => _AdminChatDetailViewState();
}

class _AdminChatDetailViewState extends State<AdminChatDetailView> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _msgController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ChatService>(context, listen: false).setHighSpeedPolling(true);
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    try {
      Provider.of<ChatService>(context, listen: false).setHighSpeedPolling(false);
    } catch (_) {}
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatService>(
      builder: (context, chatService, _) {
       if (chatService.isThreadLoading && chatService.currentThread == null) return const Center(child: CircularProgressIndicator());
       if (chatService.currentThread == null) return const Center(child: Text("Select a chat."));
       final thread = chatService.currentThread!;
       final userName = thread['userId'] != null ? thread['userId']['name'] : "User";
       const isDark = true; 

       final auth = Provider.of<AuthService>(context, listen: false);
       final currentUserId = (auth.currentUser?['_id'] ?? auth.currentUser?['id'])?.toString();
       final assignedToId = thread['assignedToAdminId']?.toString();
       final isAssignedToMe = assignedToId != null && assignedToId == currentUserId;
       final isPickedUp = thread['status'] == 'picked_up';

       return Column(
          children: [
            // Chat Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white10)),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      if (isPickedUp)
                         Text("Assigned to: ${thread['assignedToAdminName'] ?? 'Unknown Admin'}", style: const TextStyle(color: Colors.white38, fontSize: 10))
                      else if (thread['status'] == 'resolved')
                         const Text("Status: RESOLVED", style: TextStyle(color: Colors.green, fontSize: 10))
                      else
                         const Text("Status: OPEN", style: TextStyle(color: Colors.orangeAccent, fontSize: 10)),
                    ],
                  ),
                  const Spacer(),
                  if (!isPickedUp && thread['status'] != 'resolved')
                     _buildActionChip(
                       Icons.pan_tool_outlined,
                       "Pick Up",
                       () => chatService.pickupThread(thread['_id']),
                       color: Colors.blue
                     ),
                  
                  if (isAssignedToMe && isPickedUp) ...[
                    _buildActionChip(
                      Icons.check_circle_outline,
                      "Resolve",
                      () => chatService.updateThreadStatus(thread['_id'], 'resolved'),
                      color: Colors.green
                    ),
                    const SizedBox(width: 8),
                    _buildActionChip(
                      Icons.swap_horiz,
                      "Transfer",
                      () => _showTransferDialog(context, chatService, thread['_id']),
                      color: Colors.orangeAccent
                    ),
                  ],
                  
                  if (thread['status'] == 'resolved')
                    _buildActionChip(
                      Icons.replay,
                      "Reopen",
                      () => chatService.updateThreadStatus(thread['_id'], 'open'),
                      color: Colors.blue
                    ),
                ],
              ),
            ),
            // Messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: chatService.messages.length,
                itemBuilder: (context, index) {
                   final msg = chatService.messages[index];
                   final isAdmin = msg['senderType'] == 'admin';
                   final createdAt = DateTime.tryParse(msg['createdAt'] ?? '')?.toLocal() ?? DateTime.now();
                   final orderId = msg['orderId'];
                   return _buildMessageBubble(msg['messageText'] ?? '', createdAt, isAdmin, isDark, orderId: orderId);
                },
              ),
            ),
            // Input
            // Input or Assignment Notification
            if (isPickedUp && !isAssignedToMe)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                color: Colors.blue.withOpacity(0.1),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Conversation assigned to ${thread['assignedToAdminName'] ?? 'another admin'}",
                        style: const TextStyle(color: Colors.blue, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              )
            else if (thread['status'] == 'resolved')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                color: Colors.green.withOpacity(0.1),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "This ticket is resolved. Reopen to reply.",
                        style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              )
            else if (!isPickedUp && thread['status'] == 'open')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                color: Colors.orange.withOpacity(0.1),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "Pick up this conversation to start replying.",
                        style: TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton(
                      onPressed: () => chatService.pickupThread(thread['_id']),
                      child: const Text("Pick Up Now"),
                    )
                  ],
                ),
              )
            else
              Container(
                padding: EdgeInsets.only(
                  top: 15,
                  left: 15,
                  right: 15,
                  bottom: MediaQuery.of(context).viewInsets.bottom > 0 
                      ? MediaQuery.of(context).viewInsets.bottom + 10 
                      : MediaQuery.of(context).padding.bottom + 10,
                ),
                decoration: BoxDecoration(
                  border: const Border(top: BorderSide(color: Colors.white10)),
                  color: Colors.black.withOpacity(0.6), 
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _msgController,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        style: const TextStyle(color: Colors.white), 
                        decoration: InputDecoration(
                          hintText: "Type a reply...",
                          hintStyle: const TextStyle(fontSize: 14, color: Colors.white54),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: (_msgController.text.trim().isEmpty || _isSending) 
                          ? null 
                          : () async {
                            final text = _msgController.text.trim();
                            // INSTANT UI FEEDBACK
                            _msgController.clear();
                            setState(() => _isSending = true);
                            
                            try {
                              await chatService.sendMessage(text, senderType: 'admin');
                            } catch (e) {
                              // If it fails, maybe restore the text or show error
                              // but for now, we rely on chat_service marking it 'failed'
                            }
                            
                            if (mounted) {
                              setState(() => _isSending = false);
                              Future.delayed(const Duration(milliseconds: 100), () => _scrollToBottom());
                            }
                          },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          color: (_msgController.text.trim().isEmpty || _isSending) 
                              ? Colors.grey.withOpacity(0.3) 
                              : AppTheme.primaryColor,
                          shape: BoxShape.circle
                        ),
                        child: Center(
                          child: _isSending
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
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3))
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
            margin: const EdgeInsets.only(bottom: 2),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isAdmin ? AppTheme.primaryColor : Colors.white10,
              borderRadius: BorderRadius.circular(12).copyWith(
                bottomRight: isAdmin ? Radius.zero : const Radius.circular(12),
                bottomLeft: isAdmin ? const Radius.circular(12) : Radius.zero,
              ),
            ),
            child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
            child: Text(DateFormat('h:mm a').format(time), style: const TextStyle(color: Colors.white38, fontSize: 8)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStatusBadge(dynamic thread) {
    String status = (thread['status'] ?? 'open').toString().toUpperCase();
    Color color = Colors.orangeAccent;
    String label = status;

    if (status == 'RESOLVED') {
      color = Colors.green;
    } else if (status == 'PICKED_UP') {
      color = Colors.blue;
      label = "PICKED UP - ${thread['assignedToAdminName'] ?? 'Admin'}";
    }

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5), width: 0.5)
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  void _showTransferDialog(BuildContext context, ChatService chatService, String threadId) {
    // For simplicity, we'll fetch all admins. 
    // Usually this would be in a provider, but we'll use a simple dialog for now.
    // In a real implementation, you'd want a list of admins from the AuthService or UserProvider.
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text("Transfer Conversation", style: TextStyle(color: Colors.white)),
          content: const Text("Would you like to transfer this conversation to a Master Admin for further assistance?", style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
              onPressed: () async {
                // In this simplified version, we'll look for a master admin on the backend.
                // The backend transfer route handles finding the target admin if we provide a specific ID,
                // but for now let's just use a placeholder logic or prompt for an ID.
                // Let's assume we want to transfer to 'master_admin_id' (to be replaced by real logic)
                // For now, I'll just show a "Coming Soon" or a simple text field.
                
                final TextEditingController adminIdController = TextEditingController();
                Navigator.pop(context); // Close first dialog
                
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF1A1A1A),
                    title: const Text("Enter Admin ID", style: TextStyle(color: Colors.white)),
                    content: TextField(
                      controller: adminIdController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: "Admin ID",
                        hintStyle: TextStyle(color: Colors.white24),
                      ),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                      ElevatedButton(
                        onPressed: () async {
                          if (adminIdController.text.isNotEmpty) {
                            await chatService.transferThread(threadId, adminIdController.text.trim());
                            if (mounted) Navigator.pop(context);
                          }
                        },
                        child: const Text("Transfer"),
                      ),
                    ],
                  ),
                );
              },
              child: const Text("Transfer"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionChip(IconData icon, String label, VoidCallback onTap, {Color color = AppTheme.primaryColor}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          border: Border.all(color: color.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// Mobile Full Screen Chat
class AdminMobileChatDetailScreen extends StatelessWidget {
  final String threadId;
  const AdminMobileChatDetailScreen({super.key, required this.threadId});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor, // Ensure dark
        appBar: AppBar(
          title: const Text("Chat", style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: BackButton(color: Colors.white, onPressed: () => Navigator.pop(context)),
        ),
        body: LiquidBackground(
          child: Padding(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 60),
            child: AdminChatDetailView(threadId: threadId),
          ),
        ),
      ),
    );
  }
}
