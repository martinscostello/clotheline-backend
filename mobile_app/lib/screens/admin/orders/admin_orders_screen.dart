import 'package:flutter/material.dart';
import 'dart:async';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/glass/GlassContainer.dart';
import '../../../../widgets/glass/LiquidBackground.dart';
import 'package:provider/provider.dart';
import '../../../../services/order_service.dart';
import '../../../../models/order_model.dart';
import 'package:intl/intl.dart';
import 'admin_order_detail_screen.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> with SingleTickerProviderStateMixin {
  Timer? _refreshTimer;
  late TabController _tabController;
  final List<String> _tabs = ["New", "InProgress", "Ready", "Completed", "Cancelled"];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    // Fetch orders on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchOrders();
    });
    // Auto-refresh every 15 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) _fetchOrders(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchOrders({bool silent = false}) async {
    // If not silent, we could show a loader, but for now we rely on Provider's internal state or just silent update
    await Provider.of<OrderService>(context, listen: false).fetchOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Manage Orders", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        leading: const BackButton(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppTheme.primaryColor,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => Provider.of<OrderService>(context, listen: false).fetchOrders(),
          )
        ],
      ),
      body: LiquidBackground(
        child: Consumer<OrderService>(
          builder: (context, orderService, child) {
            if (orderService.orders.isEmpty) {
              // Check if loading? OrderService doesn't expose loading state easily yet, assume empty if 0
              // But we can just show empty state
              return const Center(child: Text("No orders found", style: TextStyle(color: Colors.white54)));
            }

            return TabBarView(
              controller: _tabController,
              children: _tabs.map((status) {
                // Filter Orders
                final orders = orderService.orders.where((o) => o.status.name == status).toList();
                
                if (orders.isEmpty) {
                  return Center(child: Text("No $status orders", style: const TextStyle(color: Colors.white30)));
                }

                return RefreshIndicator(
                  onRefresh: () => _fetchOrders(),
                  color: AppTheme.primaryColor,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 140, 20, 100),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return _buildOrderCard(order);
                    },
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AdminOrderDetailScreen(order: order)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        child: GlassContainer(
          opacity: 0.1,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("#${order.id.substring(order.id.length - 6)}", style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                    _buildStatusBadge(order.status.name),
                  ],
                ),
                const SizedBox(height: 10),
                Text(order.guestName ?? "Guest", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                Text(DateFormat('MMM dd, hh:mm a').format(order.date), style: const TextStyle(color: Colors.white38, fontSize: 12)),
                const Divider(color: Colors.white10, height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("${order.items.length} Items", style: const TextStyle(color: Colors.white70)),
                    Text("₦${order.totalAmount.toStringAsFixed(0)}", style: const TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'New': color = Colors.blue; break;
      case 'InProgress': color = Colors.orange; break;
      case 'Ready': color = Colors.purple; break;
      case 'Completed': color = Colors.green; break;
      case 'Cancelled': color = Colors.red; break;
      default: color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5))
      ),
      child: Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}
