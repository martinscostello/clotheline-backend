import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:laundry_app/theme/app_theme.dart';
import 'package:laundry_app/widgets/glass/LaundryGlassBackground.dart';
import 'package:laundry_app/widgets/glass/UnifiedGlassHeader.dart';
import 'package:laundry_app/widgets/glass/LaundryGlassCard.dart';
import '../../../services/order_service.dart';
import '../../../services/store_service.dart';
import '../../../services/chat_service.dart';
import '../../../models/order_model.dart';
import '../../../models/store_product.dart';
import '../../../utils/currency_formatter.dart';
import 'package:intl/intl.dart';
import '../chat/chat_screen.dart';
import '../chat/support_tickets_screen.dart';

class SupportHubScreen extends StatefulWidget {
  const SupportHubScreen({super.key});

  @override
  State<SupportHubScreen> createState() => _SupportHubScreenState();
}

class _SupportHubScreenState extends State<SupportHubScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderService>().fetchOrders(role: 'user');
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: LaundryGlassBackground(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(top: 120, bottom: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Header Text
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      "Hi, how can we help you?",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.orangeAccent : Colors.orange.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: "Have any questions? Ask them here!",
                          hintStyle: TextStyle(color: secondaryTextColor, fontSize: 14),
                          border: InputBorder.none,
                          suffixIcon: Icon(Icons.search, color: AppTheme.primaryColor),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // 3. Categories
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _buildCategoryBtn("Return & Refund", Icons.assignment_return_outlined, Colors.orange, isDark),
                        const SizedBox(width: 12),
                        _buildCategoryBtn("Delivery", Icons.local_shipping_outlined, Colors.green, isDark),
                        const SizedBox(width: 12),
                        _buildCategoryBtn("Promotions", Icons.local_offer_outlined, Colors.red, isDark),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // 4. Order Help Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      "Select an order to get help with items, shipping, return or refund problems, etc.",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildOrderSection(isDark, textColor, secondaryTextColor),
                ],
              ),
            ),

            Positioned(
              top: 0, left: 0, right: 0,
              child: UnifiedGlassHeader(
                isDark: isDark,
                title: Text("Support", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                onBack: () => Navigator.pop(context),
                actions: [
                  IconButton(
                    icon: Icon(Icons.forum_outlined, color: textColor),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportTicketsScreen())),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBtn(String label, IconData icon, Color color, bool isDark) {
    return Container(
      width: 110,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSection(bool isDark, Color textColor, Color secondaryTextColor) {
    return Consumer<OrderService>(
      builder: (context, service, _) {
        final orders = service.orders;

        if (service.orders.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: Text("No recent orders found.")),
          );
        }

        return SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: orders.length > 5 ? 5 : orders.length, // Show last 5
            itemBuilder: (context, index) {
              final order = orders[index];
              return _buildOrderCard(order, isDark, textColor, secondaryTextColor);
            },
          ),
        );
      },
    );
  }

  Widget _buildOrderCard(OrderModel order, bool isDark, Color textColor, Color secondaryTextColor) {
    final dateStr = DateFormat('MMM d').format(order.date);
    final statusColor = _getStatusColor(order.status);

    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 16),
      child: InkWell(
        onTap: () => _showOrderHelpActions(order),
        child: LaundryGlassCard(
          opacity: isDark ? 0.12 : 0.18, // Boosted for light mode visibility
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      order.status.name,
                      style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    "${order.items.length} items • ${CurrencyFormatter.format(order.totalAmount)}",
                    style: TextStyle(color: secondaryTextColor, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "Order #${order.id.substring(order.id.length - 6).toUpperCase()} • $dateStr",
                style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: order.items.length,
                  itemBuilder: (ctx, idx) {
                    final item = order.items[idx];
                    return _buildItemThumbnail(item, isDark);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemThumbnail(OrderItem item, bool isDark) {
    // Try to find image from StoreService
    String? imageUrl;
    final store = context.read<StoreService>();
    try {
      final product = store.products.firstWhere((p) => p.id == item.itemId);
      if (product.imageUrls.isNotEmpty) imageUrl = product.imageUrls.first;
    } catch (_) {}

    return Container(
      width: 50,
      height: 50,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        image: imageUrl != null
            ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
            : null,
      ),
      child: imageUrl == null
          ? Icon(
              item.itemType == "Service" ? Icons.local_laundry_service_outlined : Icons.shopping_bag_outlined,
              size: 20,
              color: Colors.grey,
            )
          : null,
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.Completed: return Colors.green;
      case OrderStatus.Cancelled: return Colors.red;
      case OrderStatus.InProgress: return Colors.blue;
      case OrderStatus.PendingUserConfirmation: return Colors.orange;
      default: return Colors.orange;
    }
  }

  void _showOrderHelpActions(OrderModel order) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _OrderHelpBottomSheet(order: order),
    );
  }
}

class _OrderHelpBottomSheet extends StatefulWidget {
  final OrderModel order;
  const _OrderHelpBottomSheet({required this.order});

  @override
  State<_OrderHelpBottomSheet> createState() => _OrderHelpBottomSheetState();
}

class _OrderHelpBottomSheetState extends State<_OrderHelpBottomSheet> {
  String? _activeAction;
  final TextEditingController _reasonController = TextEditingController();
  bool _isSending = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 24,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 40,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "How can we help with this order?",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Order #${widget.order.id.substring(widget.order.id.length - 6).toUpperCase()}",
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 24),

          if (_activeAction == null) ...[
            _buildActionTile("Track Order", "See current status and location", Icons.location_on_outlined, () {
               setState(() => _activeAction = "Track Order");
            }),
            _buildActionTile("Cancel Order", "I want to stop this order", Icons.cancel_outlined, () {
               setState(() => _activeAction = "Cancel Order");
            }),
            _buildActionTile("Refund Order", "Request money back", Icons.monetization_on_outlined, () {
               setState(() => _activeAction = "Refund Order");
            }),
            _buildActionTile("Other help with this order", "Talk to an agent", Icons.chat_bubble_outline, () {
               setState(() => _activeAction = "Other help");
            }),
          ] else ...[
            Text(
              _activeAction == "Track Order" ? "Status Update" : "Reason for $_activeAction",
              style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
            ),
            const SizedBox(height: 12),
            if (_activeAction == "Track Order")
               Container(
                 padding: const EdgeInsets.all(16),
                 decoration: BoxDecoration(
                   color: AppTheme.primaryColor.withOpacity(0.1),
                   borderRadius: BorderRadius.circular(12),
                 ),
                 child: Row(
                   children: [
                     const Icon(Icons.info_outline, color: AppTheme.primaryColor),
                     const SizedBox(width: 12),
                     Expanded(child: Text("Current status: ${widget.order.status.name}", style: const TextStyle(fontWeight: FontWeight.w600))),
                   ],
                 ),
               )
            else
              TextField(
                controller: _reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "Tell us more...",
                  filled: true,
                  fillColor: isDark ? Colors.white10 : Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSending ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSending 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(_activeAction == "Track Order" ? "I need more details" : "Submit Request"),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _activeAction = null),
              child: const Center(child: Text("Go back")),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildActionTile(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: onTap,
    );
  }

  Future<void> _submitRequest() async {
    setState(() => _isSending = true);
    
    final orderIdShort = widget.order.id.substring(widget.order.id.length - 6).toUpperCase();
    String message = "🎟️ *SUPPORT TICKET* - $_activeAction\n";
    message += "📦 Order: #$orderIdShort\n";
    message += "📅 Date: ${DateFormat('MMM d').format(widget.order.date)}\n";
    message += "--------------------------\n";
    message += "🛒 ITEMS:\n";
    for (var item in widget.order.items) {
      message += "• ${item.quantity}x ${item.name}${item.variant != null ? ' (${item.variant})' : ''}\n";
    }
    message += "--------------------------\n";
    
    if (_reasonController.text.isNotEmpty) {
      message += "💬 MESSAGE: ${_reasonController.text}";
    } else if (_activeAction == "Track Order") {
       message += "❓ Status: ${widget.order.status.name}. User needs detailed tracking info.";
    }

    try {
      final chat = context.read<ChatService>();
      
      // ENSURE THREAD IS INITIALIZED (e.g. branch info is set)
      if (chat.currentThread == null) {
        // Find which branch this order belongs to
        final branchId = widget.order.branchId;
        if (branchId == null) throw "Order has no branch ID. Cannot start support chat.";
        
        // This initiates the thread on-the-fly
        // We'll await it so we don't return early
        await chat.initThread(branchId); 
      }

      await chat.sendMessage(message, orderId: widget.order.id);
      
      if (mounted) {
        Navigator.pop(context); // Close bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Support request sent! An agent will respond shortly.")),
        );
        Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(orderId: widget.order.id)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}
