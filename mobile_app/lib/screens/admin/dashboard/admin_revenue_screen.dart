import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:laundry_app/theme/app_theme.dart';
import 'package:laundry_app/widgets/glass/LiquidBackground.dart';
import 'package:laundry_app/widgets/glass/GlassContainer.dart';
import '../../../services/order_service.dart';
import '../../../models/order_model.dart';
import '../../../utils/currency_formatter.dart';
import 'package:intl/intl.dart';
import '../orders/admin_order_detail_screen.dart';

class AdminRevenueScreen extends StatefulWidget {
  const AdminRevenueScreen({super.key});

  @override
  State<AdminRevenueScreen> createState() => _AdminRevenueScreenState();
}

class _AdminRevenueScreenState extends State<AdminRevenueScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OrderService>(context, listen: false).fetchOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Revenue", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        leading: const BackButton(color: Colors.white),
        elevation: 0,
      ),
      body: LiquidBackground(
        child: Consumer<OrderService>(
          builder: (context, orderService, _) {
            // Filter Completed Only
            final completedOrders = orderService.orders.where((o) => o.status == OrderStatus.Completed).toList();
            // Sort by Date Desc
            completedOrders.sort((a,b) => b.date.compareTo(a.date));

            double totalRevenue = completedOrders.fold(0.0, (sum, o) => sum + o.totalAmount);

            return Column(
              children: [
                // Header (Total)
                Padding(
                  padding: const EdgeInsets.only(top: 100, left: 20, right: 20, bottom: 20),
                  child: GlassContainer(
                    opacity: 0.2,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Text("Total Revenue", style: TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 5),
                        Text(
                          CurrencyFormatter.format(totalRevenue),
                          style: const TextStyle(color: AppTheme.primaryColor, fontSize: 32, fontWeight: FontWeight.bold)
                        ),
                        const SizedBox(height: 5),
                        Text("${completedOrders.length} Completed Orders", style: const TextStyle(color: Colors.white38, fontSize: 12)),
                      ],
                    ),
                  ),
                ),

                // List
                Expanded(
                  child: completedOrders.isEmpty 
                    ? const Center(child: Text("No completed orders yet", style: TextStyle(color: Colors.white54)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                        itemCount: completedOrders.length,
                        itemBuilder: (context, index) {
                          final order = completedOrders[index];
                          return _buildOrderCard(context, order);
                        },
                      ),
                )
              ],
            );
          }
        ),
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, OrderModel order) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => AdminOrderDetailScreen(order: order)));
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GlassContainer(
          opacity: 0.1,
          padding: const EdgeInsets.all(15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text("#${order.id.substring(order.id.length - 6).toUpperCase()}", style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 4),
                   Text(order.userName ?? order.guestName ?? "Guest", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                   Text(DateFormat('MMM dd, hh:mm a').format(order.date), style: const TextStyle(color: Colors.white38, fontSize: 12)),
                 ],
               ),
               Text(CurrencyFormatter.format(order.totalAmount), style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}
