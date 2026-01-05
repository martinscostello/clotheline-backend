import 'package:flutter/material.dart';
import 'dart:async';
import 'package:laundry_app/widgets/glass/LiquidBackground.dart';
import 'package:laundry_app/widgets/glass/GlassContainer.dart';
import 'package:laundry_app/theme/app_theme.dart';
import 'package:laundry_app/services/order_service.dart';
import 'package:laundry_app/models/order_model.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final OrderService _orderService = OrderService();
  bool _isLoading = true;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadOrders();
    // Auto-refresh every 15 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) _loadOrders(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders({bool silent = false}) async {
    await _orderService.fetchOrders();
    if (mounted && !silent) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Manage Orders", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: AppTheme.secondaryColor), onPressed: () {
            setState(() => _isLoading = true);
            _loadOrders();
          })
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.secondaryColor,
          labelColor: AppTheme.secondaryColor,
          unselectedLabelColor: Colors.white54,
          isScrollable: true,
          tabs: const [
            Tab(text: "New Requests"),
            Tab(text: "In Progress"),
            Tab(text: "Ready/Delivering"),
            Tab(text: "Completed"),
          ],
        ),
      ),
      body: LiquidBackground(
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOrderList([OrderStatus.New], Colors.blue),
                _buildOrderList([OrderStatus.InProgress], Colors.orange),
                _buildOrderList([OrderStatus.Ready], Colors.purple),
                _buildOrderList([OrderStatus.Completed, OrderStatus.Cancelled], Colors.green),
              ],
            ),
      ),
    );
  }

  Widget _buildOrderList(List<OrderStatus> statuses, Color color) {
    final filteredOrders = _orderService.orders.where((o) => statuses.contains(o.status)).toList();
    
    if (filteredOrders.isEmpty) {
      return const Center(child: Text("No orders found", style: TextStyle(color: Colors.white54)));
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 150, bottom: 100, left: 15, right: 15),
      itemCount: filteredOrders.length,
      itemBuilder: (context, index) {
        final order = filteredOrders[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 15),
          child: GlassContainer(
            opacity: 0.1,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Order #${order.id.substring(order.id.length - 6).toUpperCase()}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                      child: Text(order.status.name.toUpperCase(), style: TextStyle(color: color, fontSize: 10)),
                    )
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: Colors.white54),
                    const SizedBox(width: 5),
                    Text(order.guestName ?? "Unknown User", style: const TextStyle(color: Colors.white70)),
                    const SizedBox(width: 15),
                    const Icon(Icons.location_on, size: 16, color: Colors.white54),
                     const SizedBox(width: 5),
                    Text(order.pickupOption, style: const TextStyle(color: Colors.white70)),
                  ],
                ),
                const SizedBox(height: 5),
                Text("${order.items.length} Items - ₦${order.totalAmount.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                const Divider(color: Colors.white10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // View Details
                    TextButton(
                      onPressed: () => _showOrderDetails(order), 
                      child: const Text("View Details")
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondaryColor.withOpacity(0.5),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _showStatusUpdateDialog(context, order), 
                      child: const Text("Update Status")
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  void _showOrderDetails(OrderModel order) {
    showModalBottomSheet(
      context: context, 
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Order Items", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ...order.items.map((item) => ListTile(
                title: Text(item.name, style: const TextStyle(color: Colors.white)),
                subtitle: Text("${item.quantity}x @ ₦${item.price} (${item.itemType})", style: const TextStyle(color: Colors.white54)),
                trailing: Text("₦${(item.price * item.quantity).toStringAsFixed(0)}", style: const TextStyle(color: AppTheme.secondaryColor)),
              )),
              const Divider(color: Colors.white24),
              Text("Logistics", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Text("Pickup: ${order.pickupOption}", style: const TextStyle(color: Colors.white70)),
              if (order.pickupAddress != null) Text("Address: ${order.pickupAddress}", style: const TextStyle(color: Colors.white54)),
              if (order.pickupPhone != null) Text("Phone: ${order.pickupPhone}", style: const TextStyle(color: Colors.white54)),
              const SizedBox(height: 5),
              Text("Delivery: ${order.deliveryOption}", style: const TextStyle(color: Colors.white70)),
              if (order.deliveryAddress != null) Text("Address: ${order.deliveryAddress}", style: const TextStyle(color: Colors.white54)),
              if (order.deliveryPhone != null) Text("Phone: ${order.deliveryPhone}", style: const TextStyle(color: Colors.white54)),
            ],
          ),
        )
      )
    );
  }

  void _showStatusUpdateDialog(BuildContext context, OrderModel order) {
    showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF101020),
        title: const Text("Update Status", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: OrderStatus.values.map((status) {
            if (status == order.status) return const SizedBox();
            return ListTile(
              title: Text(status.name, style: const TextStyle(color: Colors.white70)),
              onTap: () async {
                 Navigator.pop(context);
                 setState(() => _isLoading = true);
                 await _orderService.updateStatus(order.id, status.name);
                 setState(() => _isLoading = false);
              },
            );
          }).toList(),
        ),
      )
    );
  }
}
