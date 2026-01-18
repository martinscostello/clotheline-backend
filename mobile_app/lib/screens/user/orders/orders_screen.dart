import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:laundry_app/widgets/glass/GlassContainer.dart';
import 'package:laundry_app/widgets/glass/LiquidBackground.dart';
import 'package:laundry_app/theme/app_theme.dart';
import '../../../utils/currency_formatter.dart';
import '../../../services/cart_service.dart';
import '../../../services/order_service.dart';
import '../../../models/order_model.dart';
import '../booking/checkout_screen.dart';
import 'package:intl/intl.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final CartService _cartService = CartService();
  final OrderService _orderService = OrderService();
  bool _isLoading = true;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
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
    if (mounted && !silent) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white70 : Colors.black54;

    return DefaultTabController(
      length: 4, 
      child: Scaffold(
        backgroundColor: isDark ? Colors.transparent : const Color(0xFFF8F9FF),
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text("My Orders", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: textColor),
              onPressed: () {
                setState(() => _isLoading = true);
                _fetchOrders();
              },
            )
          ],
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: AppTheme.primaryColor,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: isDark ? Colors.white54 : Colors.black45,
            tabs: const [
              Tab(text: "My Bucket"),
              Tab(text: "Pending"), // New + InProgress
              Tab(text: "Delivered"), // Ready + Completed
              Tab(text: "Cancelled"), // Cancelled
            ],
          ),
        ),
        body: isDark 
          ? LiquidBackground(
              child: _buildTabBarView(isDark, textColor, secondaryTextColor),
            )
          : Padding(
              // Add top padding only in light mode to account for transparent app bar if needed, 
              // actually LiquidBackground does this implicitly or extended body?
              // extendBodyBehindAppBar is true. So we need padding if we remove LiquidBackground?
              // LiquidBackground usually handles full screen. 
              // Let's just return the same child structure.
              padding: EdgeInsets.zero, 
              child: _buildTabBarView(isDark, textColor, secondaryTextColor),
            ),
      ),
    );
  }

  Widget _buildTabBarView(bool isDark, Color textColor, Color secondaryTextColor) {
    return TabBarView(
      children: [
        _buildBucketTab(isDark, textColor, secondaryTextColor),
        _buildOrderList([OrderStatus.New, OrderStatus.InProgress], isDark, textColor, secondaryTextColor), 
        _buildOrderList([OrderStatus.Ready, OrderStatus.Completed], isDark, textColor, secondaryTextColor),
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
                  padding: const EdgeInsets.only(top: 220, bottom: 20, left: 20, right: 20), // [FIX] Increased Padding
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
            Container(
              padding: const EdgeInsets.fromLTRB(16, 3, 16, 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.black45 : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -4))
                ]
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
            // Floating padding restored to clear Navbar
            const SizedBox(height: 90), 
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
      child: isDark 
        ? GlassContainer(opacity: 0.1, padding: EdgeInsets.zero, child: content)
        : Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5), spreadRadius: 1)
              ]
            ),
            child: content,
          ),
    );
  }

  Widget _buildOrderList(List<OrderStatus> statuses, bool isDark, Color textColor, Color secondaryTextColor) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Filter orders
    final filtered = _orderService.orders.where((o) => statuses.contains(o.status)).toList();
    // Sort by date desc
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

    return ListenableBuilder(
      listenable: _orderService,
      builder: (context, _) {
        return RefreshIndicator(
        onRefresh: () => _fetchOrders(),
        color: AppTheme.primaryColor,
        child: ListView.builder(
          padding: const EdgeInsets.only(top: 220, bottom: 100, left: 20, right: 20), // [FIX] Adjusted Padding
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final order = filtered[index];
            final dateStr = DateFormat('MMM d, h:mm a').format(order.date);
            
            final content = Padding(
              padding: const EdgeInsets.all(16), // Padding inside card
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Order #${order.id.substring(order.id.length - 6).toUpperCase()}", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                      _buildStatusBadge(order.status),
                    ],
                  ),
                  const SizedBox(height: 10),
                   Text("${order.items.length} Items • ${CurrencyFormatter.format(order.totalAmount)}", style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text(dateStr, style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 12)),
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
                padding: const EdgeInsets.only(bottom: 15),
                child: isDark 
                  ? GlassContainer(opacity: 0.1, child: content)
                  : Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                           // [FIX] Soft Shadow
                           BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5), spreadRadius: 1)
                        ]
                      ),
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
      case OrderStatus.New: 
      case OrderStatus.InProgress: color = Colors.orange; break;
      case OrderStatus.Ready: 
      case OrderStatus.Completed: color = Colors.green; break;
      case OrderStatus.Cancelled: color = Colors.red; break;
      case OrderStatus.Refunded: color = Colors.pinkAccent; break; // [Added]
      default: color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(status.name.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
