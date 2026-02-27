import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:clotheline_customer/widgets/glass/LaundryGlassCard.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import '../booking/checkout_screen.dart';
import 'package:intl/intl.dart';
import 'order_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_customer/widgets/glass/UnifiedGlassHeader.dart';
import '../../../widgets/dialogs/guest_login_dialog.dart';
import 'package:clotheline_core/clotheline_core.dart';
import '../../../widgets/booking/split_checkout_modal.dart';
import '../../../utils/order_status_resolver.dart';
import 'package:clotheline_core/clotheline_core.dart';
import '../chat/support_tickets_screen.dart';

class OrdersScreen extends StatefulWidget {
  final int initialIndex;
  const OrdersScreen({super.key, this.initialIndex = 0});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final CartService _cartService = CartService();
  late OrderService _orderService;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _orderService = Provider.of<OrderService>(context, listen: false);
    _fetchOrders();
    // Initial Chat Fetch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatService>().fetchMyThreads();
    });
    // Auto-refresh every 15 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) {
        _fetchOrders(silent: true);
        context.read<ChatService>().fetchMyThreads();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchOrders({bool silent = false}) async {
    await _orderService.fetchOrders();
    // [Auto-Read Policy] Mark all order-related notifications as read
    if (mounted) {
       Provider.of<NotificationService>(context, listen: false).markAllReadByType('order');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white70 : Colors.black54;

    return DefaultTabController(
      length: 7, 
      initialIndex: widget.initialIndex, // [NEW] 
      child: Scaffold(
        backgroundColor: Colors.transparent, // Consistent Global Background
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            // 1. CONTENT
            _buildTabBarView(isDark, textColor, secondaryTextColor),
            
            // 2. HEADER
            Positioned(
              top: 0, left: 0, right: 0,
              child: UnifiedGlassHeader(
                isDark: isDark,
                height: 60, // [FIX] Base height reduced, padding handled by header internally
                title: Text("My Orders", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
                actions: [
                  Consumer<ChatService>(
                    builder: (context, chat, _) {
                      final unread = chat.totalUnreadCount;
                      return Stack(
                        children: [
                          IconButton(
                            icon: Icon(Icons.forum_outlined, color: textColor, size: 24),
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportTicketsScreen())),
                          ),
                          if (unread > 0)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                                child: Text(unread.toString(), style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                              ),
                            ),
                        ],
                      );
                    }
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh, color: textColor, size: 24),
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      _fetchOrders();
                      context.read<ChatService>().fetchMyThreads();
                    },
                  )
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(kTextTabBarHeight),
                  child: ListenableBuilder(
                    listenable: Listenable.merge([_orderService, _cartService]),
                    builder: (context, _) {
                      final bucketCount = _cartService.items.length + _cartService.storeItems.length;
                      final newCount = _orderService.orders.where((o) => o.status == OrderStatus.New).length;
                      final pendingCount = _orderService.orders.where((o) => [OrderStatus.PendingUserConfirmation, OrderStatus.Inspecting].contains(o.status)).length;
                      final inProgressCount = _orderService.orders.where((o) => o.status == OrderStatus.InProgress).length;
                      final readyCount = _orderService.orders.where((o) => o.status == OrderStatus.Ready).length;
                      final completedCount = _orderService.orders.where((o) => o.status == OrderStatus.Completed).length;
                      final cancelledCount = _orderService.orders.where((o) => [OrderStatus.Cancelled, OrderStatus.Refunded].contains(o.status)).length;

                      return TabBar(
                        isScrollable: true,
                        indicatorColor: AppTheme.primaryColor,
                        labelColor: AppTheme.primaryColor,
                        unselectedLabelColor: isDark ? Colors.white54 : Colors.black45,
                        indicatorSize: TabBarIndicatorSize.label,
                        tabs: [
                          _buildTab("My Bucket", bucketCount),
                          _buildTab("New", newCount),
                          _buildTab("Pending", pendingCount),
                          _buildTab("In Progress", inProgressCount),
                          _buildTab("Ready", readyCount),
                          _buildTab("Completed", completedCount),
                          _buildTab("Cancelled", cancelledCount),
                        ],
                      );
                    }
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBarView(bool isDark, Color textColor, Color secondaryTextColor) {
    return TabBarView(
      children: [
        _buildBucketTab(isDark, textColor, secondaryTextColor),
        _buildOrderList([OrderStatus.New], isDark, textColor, secondaryTextColor), 
        _buildOrderList([OrderStatus.PendingUserConfirmation, OrderStatus.Inspecting], isDark, textColor, secondaryTextColor), 
        _buildOrderList([OrderStatus.InProgress], isDark, textColor, secondaryTextColor),
        _buildOrderList([OrderStatus.Ready], isDark, textColor, secondaryTextColor),
        _buildOrderList([OrderStatus.Completed], isDark, textColor, secondaryTextColor),
        _buildOrderList([OrderStatus.Cancelled, OrderStatus.Refunded], isDark, textColor, secondaryTextColor),
      ],
    );
  }

  Widget _buildBucketTab(bool isDark, Color textColor, Color secondaryTextColor) {
    return ListenableBuilder(
      listenable: _cartService,
      builder: (context, _) {
        if (_cartService.items.isEmpty) { 
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_basket_outlined, size: 64, color: isDark ? Colors.white24 : Colors.black26),
                const SizedBox(height: 20),
                Text("Your bucket is empty", style: TextStyle(color: secondaryTextColor, fontSize: 16)),
              ],
            ),
          );
        }

        return Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _fetchOrders(),
                color: AppTheme.primaryColor,
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: ListView(
                    padding: EdgeInsets.only(
                      top: MediaQuery.paddingOf(context).top + 60 + kTextTabBarHeight + 0, 
                      bottom: 20, left: 20, right: 20
                    ), 
                    children: [
                      // Laundry Items
                       ..._cartService.items.map((item) {
                         bool isPending = (item.quoteRequired || item.fulfillmentMode == 'deployment');
                         return _buildBucketItem(
                           title: item.item.name,
                           subtitle: item.serviceType?.name ?? "Regular Service",
                           quantity: item.quantity,
                           price: item.totalPrice,
                           isPending: isPending,
                           onDelete: () => _cartService.removeItem(item),
                           isDark: isDark, textColor: textColor, secondaryTextColor: secondaryTextColor
                         );
                       }),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
            // Checkout Summary Area
            ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 105), // Precise 105px to clear navbar closely
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF101010).withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.7),
                    border: Border(
                      top: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _cartService.activeModes.contains('deployment') ? "Payable Now" : "Total Estimate", 
                              style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold, fontSize: 14)
                            ),
                            Builder(
                              builder: (context) {
                                 bool isTotalPending = _cartService.items.any((item) => (item.quoteRequired || item.fulfillmentMode == 'deployment'));
                                 return Text(
                                   isTotalPending ? "Pending Address" : CurrencyFormatter.format(_cartService.totalAmount), 
                                   style: TextStyle(color: isTotalPending ? Colors.orange : AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: isTotalPending ? 14 : 18)
                                 );
                              }
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), 
                            ),
                            onPressed: () {
                               final auth = context.read<AuthService>();
                                if (auth.isGuest) {
                                 showDialog(
                                   context: context,
                                   builder: (ctx) => const GuestLoginDialog(
                                     message: "Please sign in or create an account to resume your checkout.",
                                   ),
                                 );
                                 return;
                               }

                               if (_cartService.hasFulfillmentConflict) {
                                 showDialog(
                                   context: context,
                                   builder: (ctx) => SplitCheckoutModal(
                                     modes: _cartService.activeModes.toList(),
                                     onSelectMode: (mode) {
                                       Navigator.pop(ctx);
                                       Navigator.of(context).push(MaterialPageRoute(
                                         builder: (context) => CheckoutScreen(fulfillmentMode: mode)
                                       ));
                                     },
                                   ),
                                 );
                                 return;
                               }

                               Navigator.of(context).push(MaterialPageRoute(
                                 builder: (context) => CheckoutScreen(
                                   fulfillmentMode: _cartService.activeModes.isNotEmpty 
                                       ? _cartService.activeModes.first 
                                       : 'logistics'
                                 )
                               ));
                             }, 
                             child: const Text("RESUME CHECKOUT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                           ),
                         )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBucketItem({
    required String title, required String subtitle, required int quantity, required double price, required VoidCallback onDelete,
    required bool isDark, required Color textColor, required Color secondaryTextColor, bool isPending = false
  }) {
    final content = Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Text("${quantity}x", style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                Text(subtitle, style: TextStyle(color: secondaryTextColor, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(isPending ? "Pending" : CurrencyFormatter.format(price), style: TextStyle(color: isPending ? Colors.orange : textColor, fontWeight: FontWeight.bold, fontSize: isPending ? 12 : 14)),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onDelete,
              ),
            ],
          )
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LaundryGlassCard(
        opacity: isDark ? 0.12 : 0.05,
        padding: EdgeInsets.zero,
        child: content,
      ),
    );
  }
  Widget _buildOrderList(List<OrderStatus> statuses, bool isDark, Color textColor, Color secondaryTextColor) {
    return ListenableBuilder(
      listenable: _orderService,
      builder: (context, _) {
        // [CRITICAL FIX] Filter inside builder so it updates on notifyListeners
        final filtered = _orderService.orders.where((o) => statuses.contains(o.status)).toList();
        filtered.sort((a,b) => b.date.compareTo(a.date));

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: isDark ? Colors.white24 : Colors.black26),
                const SizedBox(height: 20),
                Text("No orders in this category", style: TextStyle(color: secondaryTextColor, fontSize: 16)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => _fetchOrders(),
          color: AppTheme.primaryColor,
          backgroundColor: Colors.transparent, // [FIX] No dark background
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: ListView.builder(
              physics: const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics()), // [FIX] Prevent overscroll void
              padding: EdgeInsets.only(
                top: MediaQuery.paddingOf(context).top + 60 + kTextTabBarHeight + 0, 
                bottom: 100, left: 20, right: 20
              ),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final order = filtered[index];
                final dateStr = DateFormat('MMM d, h:mm a').format(order.date.toLocal());
                
                final content = Padding(
                  padding: const EdgeInsets.all(12), // [TIGHTER] Padding inside card
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Order #${order.id.substring(order.id.length - 6).toUpperCase()}", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                          if (order.fulfillmentMode != 'logistics')
                            _buildModeBadge(order.fulfillmentMode),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (order.fulfillmentMode == 'deployment') ...[
                        Text("On-site Deployment", style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold, fontSize: 13)),
                        if (order.pickupAddress != null)
                          Text(order.pickupAddress!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: secondaryTextColor, fontSize: 11)),
                      ] else ...[
                        Text("${order.items.length} Items • ${CurrencyFormatter.format(order.totalAmount)}", style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold, fontSize: 13)),
                        Text("${order.pickupOption} / ${order.deliveryOption}", style: TextStyle(color: secondaryTextColor, fontSize: 11)),
                      ],
                      const SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(dateStr, style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 11)),
                          Row(
                            children: [
                              if (order.laundryNotes != null && order.laundryNotes!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                                    ),
                                    child: const Text("⚠ SPECIAL CARE", style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              _buildStatusBadge(order),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );

                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => OrderDetailScreen(order: order)
                    ));
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: LaundryGlassCard(
                      opacity: isDark ? 0.12 : 0.05,
                      padding: const EdgeInsets.all(12),
                      child: content,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(OrderModel order) {
    final statusLabel = OrderStatusResolver.getDisplayStatus(order);
    final color = OrderStatusResolver.getStatusColor(order);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(statusLabel.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildModeBadge(String mode) {
    Color color = Colors.purple;
    String label = "MODE";
    if (mode == 'deployment') {
      color = Colors.teal;
      label = "ON-SITE";
    } else if (mode == 'bulky') {
      color = Colors.indigo;
      label = "BULKY";
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildTab(String label, int count) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.5)),
              ),
              child: Text(
                count.toString(),
                style: const TextStyle(color: AppTheme.primaryColor, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
