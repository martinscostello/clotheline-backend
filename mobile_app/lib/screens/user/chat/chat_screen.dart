import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/chat_service.dart';
import '../../../providers/branch_provider.dart';
import 'package:laundry_app/widgets/glass/LaundryGlassBackground.dart';
import 'package:laundry_app/widgets/glass/UnifiedGlassHeader.dart';
import 'package:laundry_app/widgets/common/user_avatar.dart';
import '../../../services/auth_service.dart';

class ChatScreen extends StatefulWidget {
  final String? orderId;
  const ChatScreen({super.key, this.orderId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}
class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

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
  void initState() {
    super.initState();
    final branchProvider = Provider.of<BranchProvider>(context, listen: false);
    final service = Provider.of<ChatService>(context, listen: false);
    
    if (branchProvider.selectedBranch != null) {
      service.startPolling(branchProvider.selectedBranch!.id);
    }
    
    _msgController.addListener(() {
      setState(() {}); // Rebuild for send button state
    });

    // If orderId is provided, pre-fill or send automated message?
    // Requirement says: "Attaches orderId as context"
    if (widget.orderId != null) {
      // Small delay to ensure thread is ready
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted && service.messages.isEmpty) {
          service.sendMessage("I have a question about Order #${widget.orderId!.substring(widget.orderId!.length-6).toUpperCase()}", orderId: widget.orderId);
        }
      });
    }

    // Scroll to bottom after init
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    Provider.of<ChatService>(context, listen: false).stopPolling();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
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
            Column(
              children: [
                Expanded(
                  child: Consumer<ChatService>(
                    builder: (context, chat, _) {
                      if (chat.isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (chat.currentThread == null) {
                        return const Center(child: Text("Could not initialize chat.", style: TextStyle(color: Colors.white54)));
                      }
            
                      return Column(
                        children: [
                          Expanded(
                            child: chat.messages.isEmpty 
                              ? _buildEmptyState(isDark)
                              : ListView.builder(
                                  controller: _scrollController,
                                  padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 110, bottom: 20, left: 16, right: 16),
                                  itemCount: chat.messages.length,
                                  itemBuilder: (context, index) {
                                    final msg = chat.messages[index];
                                    final isMe = msg['senderType'] == 'user';
                                    
                                    String? avatarId;
                                    if (msg['senderId'] is Map) {
                                      avatarId = msg['senderId']['avatarId'];
                                    }
                                    
                                    return _buildMessageBubble(msg['messageText'] ?? "", isMe, isDark, avatarId);
                                  },
                                ),
                          ),
                          _buildInputArea(isDark),
                        ],
                      );
                    }
                  ),
                ),
              ],
            ),

            // 2. Header
            Positioned(
              top: 0, left: 0, right: 0,
              child: UnifiedGlassHeader(
                isDark: isDark,
                onBack: () => Navigator.pop(context),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Laundry Support", style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                    const Text("Typically replies in minutes", style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.normal)),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: Icon(Icons.info_outline, color: isDark ? Colors.white : Colors.black54),
                    onPressed: () {},
                  )
                ],
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.support_agent, size: 48, color: isDark ? Colors.white54 : Colors.grey),
          ),
          const SizedBox(height: 16),
          Text("How can we help you today?", style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700], fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isMe, bool isDark, String? avatarId) {
    return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 6),
                child: UserAvatar(avatarId: avatarId, name: "Support", radius: 16, isDark: isDark),
              ),
            Flexible(
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                decoration: BoxDecoration(
                  color: isMe 
                    ? const Color(0xFF4A80F0) 
                    : (isDark ? const Color(0xFF1E1E2C) : Colors.white),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16)
                  ),
                  boxShadow: [
                    if (!isMe && !isDark) 
                       BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 1))
                  ]
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Text(
                    text,
                    style: TextStyle(
                      color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
            if (isMe)
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 6),
                child: Consumer<AuthService>(
                  builder: (context, auth, _) => UserAvatar(
                    avatarId: auth.currentUser?['avatarId'], 
                    name: auth.currentUser?['name'] ?? 'U', 
                    radius: 16, 
                    isDark: isDark
                  ),
                ),
              ),
          ],
        ),
      );
  }

  Widget _buildInputArea(bool isDark) {
    final canSend = _msgController.text.trim().isNotEmpty && !_isSending;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2)
          )
        ]
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 10,
        left: 10, 
        right: 10, 
        top: 10
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : const Color(0xFFF2F2F5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _msgController,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  hintText: "Message...",
                  hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
             onTap: canSend ? () async {
                final text = _msgController.text.trim();
                setState(() => _isSending = true);
                await Provider.of<ChatService>(context, listen: false).sendMessage(text, orderId: widget.orderId);
                if (mounted) {
                  _msgController.clear();
                  setState(() => _isSending = false);
                  Future.delayed(const Duration(milliseconds: 100), () => _scrollToBottom());
                }
             } : null,
             child: AnimatedContainer(
               duration: const Duration(milliseconds: 200),
               height: 48, 
               width: 48, 
               decoration: BoxDecoration(
                 shape: BoxShape.circle,
                 color: canSend ? const Color(0xFF4A80F0) : Colors.grey.withOpacity(0.3),
               ),
               child: Center(
                 child: _isSending 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(Icons.send_rounded, color: canSend ? Colors.white : Colors.white54, size: 20),
               ),
             ),
          )
        ],
      ),
    );
  }
}
