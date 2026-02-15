import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:laundry_app/theme/app_theme.dart';
import 'package:laundry_app/widgets/glass/LiquidBackground.dart';
import 'package:laundry_app/widgets/glass/GlassContainer.dart';
import 'package:laundry_app/services/auth_service.dart';
import 'package:laundry_app/utils/toast_utils.dart';
import 'package:laundry_app/services/order_service.dart';
import 'package:laundry_app/models/order_model.dart';
import 'package:intl/intl.dart';

class AdminManageDataScreen extends StatefulWidget {
  const AdminManageDataScreen({super.key});

  @override
  State<AdminManageDataScreen> createState() => _AdminManageDataScreenState();
}

class _AdminManageDataScreenState extends State<AdminManageDataScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text("Manage Data", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: LiquidBackground(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.only(top: 100, bottom: 40, left: 20, right: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWarningSection(),
                    const SizedBox(height: 30),
                    
                    _buildSectionHeader("Orders Management"),
                    const SizedBox(height: 10),
                    GlassContainer(
                      opacity: 0.1,
                      child: Column(
                        children: [
                          _buildActionTile(
                            Icons.delete_forever, 
                            "Delete All Orders", 
                            "Permanently erase all order records",
                            Colors.redAccent,
                            () => _confirmAction("Delete All Orders", "This will permanently delete every order in the database. This cannot be undone.", () => _deleteAllOrders()),
                          ),
                          _buildActionTile(
                            Icons.search, 
                            "Delete Specific Orders", 
                            "Find and remove individual orders",
                            AppTheme.primaryColor,
                            () => _showSpecificOrderSelector(),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    _buildSectionHeader("Payments & Revenue"),
                    const SizedBox(height: 10),
                    GlassContainer(
                      opacity: 0.1,
                      child: Column(
                        children: [
                          _buildActionTile(
                            Icons.payments_outlined, 
                            "Delete All Payments", 
                            "Wipe all transaction logs",
                            Colors.orangeAccent,
                            () => _confirmAction("Delete All Payments", "This will erase all payment records. Financial history will be lost.", () => _deleteAllPayments()),
                          ),
                          _buildActionTile(
                            Icons.money_off, 
                            "Clear All Revenue Data", 
                            "Reset revenue tracking and metrics",
                            Colors.deepOrange,
                            () => _confirmAction("Clear Revenue", "This will clear all revenue metrics. Safe if you're restarting for a new period.", () => _clearRevenue()),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    _buildSectionHeader("Chat & Communication"),
                    const SizedBox(height: 10),
                    GlassContainer(
                      opacity: 0.1,
                      child: Column(
                        children: [
                          _buildActionTile(
                            Icons.chat_bubble_outline, 
                            "Clear All Chat History", 
                            "Delete all messages and support threads",
                            Colors.purpleAccent,
                            () => _confirmAction("Clear Chat History", "ALL messages and support threads will be wiped. Users will see empty chats.", () => _clearChats()),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
              if (_isLoading)
                Container(
                  color: Colors.black54,
                  child: const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWarningSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
          SizedBox(width: 15),
          Expanded(
            child: Text(
              "CRITICAL: Data Management tools are for MasterAdmin use only. Actions performed here are permanent.",
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
    );
  }

  Widget _buildActionTile(IconData icon, String title, String subtitle, Color iconColor, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white24),
      onTap: onTap,
    );
  }

  void _confirmAction(String title, String message, Future<void> Function() action) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.redAccent, width: 1.5)
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL", style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              action();
            }, 
            child: const Text("CONFIRM DELETE")
          ),
        ],
      )
    );
  }

  // API ACTIONS
  Future<void> _deleteAllOrders() async {
    setState(() => _isLoading = true);
    final success = await Provider.of<AuthService>(context, listen: false).deleteAllOrders();
    setState(() => _isLoading = false);
    if (success) {
      ToastUtils.show(context, "All orders cleared successfully", type: ToastType.success);
    } else {
      ToastUtils.show(context, "Failed to clear orders", type: ToastType.error);
    }
  }

  Future<void> _deleteAllPayments() async {
    setState(() => _isLoading = true);
    final success = await Provider.of<AuthService>(context, listen: false).deleteAllPayments();
    setState(() => _isLoading = false);
    if (success) {
      ToastUtils.show(context, "All payments cleared successfully", type: ToastType.success);
    } else {
      ToastUtils.show(context, "Failed to clear payments", type: ToastType.error);
    }
  }

  Future<void> _clearRevenue() async {
    setState(() => _isLoading = true);
    final success = await Provider.of<AuthService>(context, listen: false).clearRevenueData();
    setState(() => _isLoading = false);
    if (success) {
      ToastUtils.show(context, "Revenue data reset successfully", type: ToastType.success);
    } else {
      ToastUtils.show(context, "Failed to reset revenue", type: ToastType.error);
    }
  }

  Future<void> _clearChats() async {
    setState(() => _isLoading = true);
    final success = await Provider.of<AuthService>(context, listen: false).clearChatHistory();
    setState(() => _isLoading = false);
    if (success) {
      ToastUtils.show(context, "Chat history wiped clean", type: ToastType.success);
    } else {
      ToastUtils.show(context, "Failed to clear chats", type: ToastType.error);
    }
  }

  void _showSpecificOrderSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 15),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text("Select Order to Delete", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: Consumer<OrderService>(
                    builder: (context, orderService, _) {
                      final orders = orderService.orders;
                      if (orders.isEmpty) {
                        return const Center(child: Text("No orders found", style: TextStyle(color: Colors.white54)));
                      }
                      return ListView.builder(
                        controller: scrollController,
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          return ListTile(
                            leading: const CircleAvatar(backgroundColor: Colors.white10, child: Icon(Icons.shopping_bag_outlined, color: Colors.white70, size: 18)),
                            title: Text("Order #${order.id.substring(order.id.length - 6).toUpperCase()}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Text("${DateFormat('MMM dd, hh:mm a').format(order.date)} • ${order.status.name.toUpperCase()}", style: const TextStyle(color: Colors.white54, fontSize: 11)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () {
                                Navigator.pop(context);
                                _confirmAction("Delete Order #${order.id.substring(order.id.length - 6).toUpperCase()}", "Delete this specific order record?", () async {
                                  setState(() => _isLoading = true);
                                  final success = await Provider.of<AuthService>(context, listen: false).deleteSpecificOrder(order.id);
                                  if (success) {
                                    await orderService.fetchOrders(role: 'admin');
                                  }
                                  setState(() => _isLoading = false);
                                  if (success) {
                                    ToastUtils.show(context, "Order deleted", type: ToastType.success);
                                  }
                                });
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          }
        );
      },
    );
    // Trigger fetch
    Provider.of<OrderService>(context, listen: false).fetchOrders(role: 'admin');
  }
}
