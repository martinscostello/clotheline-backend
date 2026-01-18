import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/chat_service.dart';
import '../../../providers/branch_provider.dart';
import 'package:liquid_glass_ui/liquid_glass_ui.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final branchProvider = Provider.of<BranchProvider>(context, listen: false);
    final service = Provider.of<ChatService>(context, listen: false);
    
    if (branchProvider.selectedBranch != null) {
      service.startPolling(branchProvider.selectedBranch!.id);
    }
    
    // Scroll to bottom after init
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
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
  void dispose() {
    Provider.of<ChatService>(context, listen: false).stopPolling();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Telegram-like Colors
    final bgColor = isDark ? const Color(0xFF0F0F1E) : const Color(0xFFABC2D0); // Muted Blue-Grey like Telegram Wallpaper
    // Or just clean white/black as requested "Lightweight"
    // User asked for "full-height chat screen", so let's use a solid background.
    
    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFE6EBEF), // Telegram Web-ish bg
      appBar: AppBar(
        flexibleSpace: isDark ? null : Container(decoration: const BoxDecoration(color: Colors.white)), // White header in light mode
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 1,
        shadowColor: Colors.black12,
        leading: const BackButton(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: Consumer<ChatService>(
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
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      itemCount: chat.messages.length,
                      itemBuilder: (context, index) {
                        final msg = chat.messages[index];
                        final isMe = msg['senderType'] == 'user';
                        
                        return _buildMessageBubble(msg['messageText'] ?? "", isMe, isDark, true);
                      },
                    ),
              ),
              _buildInputArea(isDark),
            ],
          );
        }
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

  Widget _buildMessageBubble(String text, bool isMe, bool isDark, bool showTime) {
    return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: isMe 
              ? const Color(0xFF4A80F0) // Brand Accent
              : (isDark ? const Color(0xFF1E1E2C) : Colors.white),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 4), // Telegram style corners
              bottomRight: Radius.circular(isMe ? 4 : 16)
            ),
            boxShadow: [
              if (!isMe && !isDark) 
                 BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 1))
            ]
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end, // For timestamp alignment
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                    fontSize: 15,
                  ),
                ),
                // Timestamp (Mock)
                const SizedBox(height: 4),
                // Icon(Icons.done_all, size: 12, color: Colors.white70) // Read receipt if needed
              ],
            ),
          ),
        ),
      );
  }

  Widget _buildInputArea(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 10,
        left: 10, 
        right: 10, 
        top: 10
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            icon: Icon(Icons.attach_file, color: isDark ? Colors.white54 : Colors.grey),
            onPressed: () {},
          ),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 100),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : const Color(0xFFF2F2F5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _msgController,
                maxLines: null,
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
             onTap: () {
                final text = _msgController.text.trim();
                if (text.isNotEmpty) {
                  Provider.of<ChatService>(context, listen: false).sendMessage(text);
                  _msgController.clear();
                  Future.delayed(const Duration(milliseconds: 100), () => _scrollToBottom());
                }
             },
             child: const SizedBox(height: 48, width: 48, 
               child: Center(
                 child: CircleAvatar(
                   radius: 24,
                   backgroundColor: Color(0xFF4A80F0),
                   child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
                 ),
               ),
             ),
          )
        ],
      ),
    );
  }
}
