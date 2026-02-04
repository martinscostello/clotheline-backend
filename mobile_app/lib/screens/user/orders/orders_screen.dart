import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:laundry_app/widgets/glass/LaundryGlassCard.dart';
import 'package:laundry_app/theme/app_theme.dart';
import '../../../utils/currency_formatter.dart';
import '../../../services/cart_service.dart';
import '../../../services/order_service.dart';
import '../../../models/order_model.dart';
import '../booking/checkout_screen.dart';
import 'package:intl/intl.dart';
import 'order_detail_screen.dart';
import 'package:provider/provider.dart';
import '../../../services/notification_service.dart';
import 'package:laundry_app/widgets/glass/UnifiedGlassHeader.dart';
import '../../../widgets/dialogs/guest_login_dialog.dart';
import '../../../services/auth_service.dart';

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
    // Auto-refresh every 15 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) _fetchOrders(silent: true);
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
                height: 70, // [REDUCED] Move tabs up further
                title: Text("My Orders", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
                actions: [
                  IconButton(
                    icon: Icon(Icons.refresh, color: textColor, size: 24), // Slightly smaller for better circle fit
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      _fetchOrders();
                    },
                  )
                ],
                bottom: TabBar(
                  isScrollable: true,
                  indicatorColor: AppTheme.primaryColor,
                  labelColor: AppTheme.primaryColor,
                  unselectedLabelColor: isDark ? Colors.white54 : Colors.black45,
                  indicatorSize: TabBarIndicatorSize.label,
                  tabs: const [
                    Tab(text: "My Bucket"),
                    Tab(text: "New"),
                    Tab(text: "Pending"),
                    Tab(text: "In Progress"),
                    Tab(text: "Ready"),
                    Tab(text: "Completed"),
                    Tab(text: "Cancelled"),
                  ],
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
        _buildOrderList([OrderStatus.PendingUserConfirmation], isDark, textColor, secondaryTextColor), 
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
                child: ListView(
                  padding: const EdgeInsets.only(top: 190, bottom: 20, left: 20, right: 20), // [ADJUSTED] Padding for higher header
                  children: [
                    // Laundry Items
                    ..._cartService.items.map((item) => _buildBucketItem(
                      title: item.item.name,
                      subtitle: item.serviceType.name,
                      quantity: item.quantity,
                      price: item.totalPrice,
                      onDelete: () => _cartService.removeItem(item),
                      isDark: isDark, textColor: textColor, secondaryTextColor: secondaryTextColor
                    )),
                    
                    // Store Items Removed

                    const SizedBox(height: 20),
                  ],
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
                    color: isDark ? const Color(0xFF101010).withOpacity(0.7) : Colors.white.withOpacity(0.7),
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
                         Text("Total Estimate", style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold, fontSize: 14)),
                         Text(CurrencyFormatter.format(_cartService.serviceTotalAmount), style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 18)),
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

                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (context) => const CheckoutScreen()
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
            // Floating padding restored to clear Navbar
            // Floating padding removed to allow bottom bar to touch edge
          ],
        );
      },
    );
  }

  Widget _buildBucketItem({
    required String title, required String subtitle, required int quantity, required double price, required VoidCallback onDelete,
    required bool isDark, required Color textColor, required Color secondaryTextColor
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
              Text(CurrencyFormatter.format(price), style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
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
        child: ListView.builder(
          physics: const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics()), // [FIX] Prevent overscroll void
          padding: const EdgeInsets.only(top: 190, bottom: 100, left: 20, right: 20),
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
                      // Badge moved to bottom to prevent overflow
                    ],
                  ),
                  const SizedBox(height: 8),
                   Text("${order.items.length} Items • ${CurrencyFormatter.format(order.totalAmount)}", style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(dateStr, style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 11)),
                      _buildStatusBadge(order.status),
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
       );
      }
    );
  }

  Widget _buildStatusBadge(OrderStatus status) {
    Color color;
    switch (status) {
      case OrderStatus.New: color = Colors.blue; break;
      case OrderStatus.InProgress: color = Colors.orange; break;
      case OrderStatus.Ready: color = Colors.cyan; break;
      case OrderStatus.Completed: color = Colors.green; break;
      case OrderStatus.Cancelled: color = Colors.red; break;
      case OrderStatus.Refunded: color = Colors.pinkAccent; break;
      case OrderStatus.PendingUserConfirmation: color = Colors.orange; break;
    }

    String label = status.name.toUpperCase();
    if (status == OrderStatus.PendingUserConfirmation) label = "PENDING CONFIRMATION";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
