import 'package:flutter/material.dart';
import 'dart:async';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/glass/GlassContainer.dart';
import '../../../../widgets/glass/LiquidBackground.dart';
import 'package:provider/provider.dart';
import '../../../../services/order_service.dart';
import '../../../../models/order_model.dart';
import 'package:intl/intl.dart';
import '../../../../models/branch_model.dart';
import '../../../../providers/branch_provider.dart';
import 'admin_order_detail_screen.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> with SingleTickerProviderStateMixin {
  // [Multi-Branch] Filter State
  Branch? _selectedBranchFilter;
  
  late TabController _tabController;
  Timer? _refreshTimer;
  final List<String> _tabs = ['New', 'InProgress', 'Ready', 'Completed', 'Cancelled'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    // Fetch orders & branches on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchOrders();
      Provider.of<BranchProvider>(context, listen: false).fetchBranches();
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
    await Provider.of<OrderService>(context, listen: false).fetchOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: _buildBranchFilterTitle(),
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
              return const Center(child: Text("No orders found", style: TextStyle(color: Colors.white54)));
            }
            
            // [Multi-Branch] Filter Logic
            List<OrderModel> filteredList = orderService.orders;
            if (_selectedBranchFilter != null) {
              filteredList = filteredList.where((o) => o.branchId == _selectedBranchFilter!.id).toList();
            }

            return TabBarView(
              controller: _tabController,
              children: _tabs.map((status) {
                // Filter Status
                final orders = filteredList.where((o) => o.status.name == status).toList();
                
                if (orders.isEmpty) {
                   String msg = "No $status orders";
                   if (_selectedBranchFilter != null) msg += " in ${_selectedBranchFilter!.name}";
                   return Center(child: Text(msg, style: const TextStyle(color: Colors.white30)));
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

  Widget _buildBranchFilterTitle() {
    return Consumer<BranchProvider>(
       builder: (context, provider, _) {
          return DropdownButton<Branch?>(
            value: _selectedBranchFilter,
            dropdownColor: Colors.black87,
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
            underline: const SizedBox(), 
            hint: const Text("All Branches", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            items: [
              const DropdownMenuItem<Branch?>(
                value: null,
                child: Text("All Branches"), // Reset filter
              ),
              ...provider.branches.map((b) => DropdownMenuItem(
                value: b,
                child: Text(b.name),
              ))
            ],
            onChanged: (Branch? value) {
              setState(() => _selectedBranchFilter = value);
            },
          );
       }
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: #ID, Name, Date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("#${order.id.substring(order.id.length - 6).toUpperCase()}", style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(order.userName ?? order.guestName ?? "Guest", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          Text(DateFormat('MMM dd, hh:mm a').format(order.date), style: const TextStyle(color: Colors.white38, fontSize: 12)),
                        ],
                      ),
                    ),
                    // Right: Status
                    _buildStatusBadge(order.status.name),
                  ],
                ),
                const Divider(color: Colors.white10, height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("${order.items.length} Items", style: const TextStyle(color: Colors.white70)),
                    // Using CurrencyFormatter implicitly by importing or local helper? 
                    // CurrencyFormatter is not imported in this file. I need to add import.
                    // Actually, I'll use a local formatted string for now or import it.
                    // Wait, I should import it.
                    Text("₦${_formatCurrency(order.totalAmount)}", style: const TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
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

  String _formatCurrency(double amount) {
    return NumberFormat("#,##0", "en_US").format(amount);
  }
}
