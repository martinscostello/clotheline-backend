import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/glass/GlassContainer.dart';
import '../../../../widgets/glass/LiquidBackground.dart';
import '../../../../models/order_model.dart';
import '../../../../services/order_service.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class AdminOrderDetailScreen extends StatefulWidget {
  final OrderModel order;
  const AdminOrderDetailScreen({super.key, required this.order});

  @override
  State<AdminOrderDetailScreen> createState() => _AdminOrderDetailScreenState();
}

class _AdminOrderDetailScreenState extends State<AdminOrderDetailScreen> {
  late String _currentStatus;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.order.status.name;
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isUpdating = true);
    final success = await Provider.of<OrderService>(context, listen: false).updateStatus(widget.order.id, newStatus);
    setState(() => _isUpdating = false);
    
    if (success) {
      setState(() => _currentStatus = newStatus);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Status updated to $newStatus")));
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to update status")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Order #${widget.order.id.substring(widget.order.id.length - 6)}", style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        leading: const BackButton(color: Colors.white),
      ),
      body: LiquidBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 100, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Status Manager
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                child: GlassContainer(
                  opacity: 0.1,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Order Status", style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            DropdownButton<String>(
                              dropdownColor: const Color(0xFF202020),
                              value: _currentStatus,
                              style: const TextStyle(color: Colors.white),
                              underline: Container(height: 1, color: AppTheme.primaryColor),
                              onChanged: _isUpdating ? null : (val) {
                                if (val != null && val != _currentStatus) _updateStatus(val);
                              },
                              items: ["New", "InProgress", "Ready", "Completed", "Cancelled"].map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s),
                              )).toList(),
                            ),
                            if (_isUpdating) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),

              // 2. Customer Info
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                child: GlassContainer(
                  opacity: 0.1,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Customer Info", style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 15),
                        _buildInfoRow(Icons.person, widget.order.guestName ?? "Guest"),
                        _buildInfoRow(Icons.phone, widget.order.guestPhone ?? "N/A"),
                        const SizedBox(height: 10),
                        const Divider(color: Colors.white10),
                        const SizedBox(height: 10),
                        const Text("Logistics", style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 5),
                        _buildInfoRow(Icons.upload, "Pickup: ${widget.order.pickupOption}"),
                        if (widget.order.pickupOption == 'Pickup') _buildInfoRow(Icons.location_on, widget.order.pickupAddress ?? "N/A", isSmall: true),
                        const SizedBox(height: 10),
                        _buildInfoRow(Icons.download, "Delivery: ${widget.order.deliveryOption}"),
                         if (widget.order.deliveryOption == 'Deliver') _buildInfoRow(Icons.location_on, widget.order.deliveryAddress ?? "N/A", isSmall: true),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Items
              const Text("Items", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ...widget.order.items.map((item) => Card(
                color: Colors.white10,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: Icon(
                    item.itemType == 'Service' ? Icons.local_laundry_service : Icons.shopping_bag,
                    color: item.itemType == 'Service' ? Colors.blueAccent : Colors.pinkAccent
                  ),
                  title: Text(item.name, style: const TextStyle(color: Colors.white)),
                  subtitle: Text(
                    item.itemType == 'Product' ? "Variant: ${item.variant ?? 'Standard'}" : "Service: ${item.serviceType}",
                    style: const TextStyle(color: Colors.white54)
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("x${item.quantity}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Text("₦${(item.price * item.quantity).toStringAsFixed(0)}", style: const TextStyle(color: AppTheme.secondaryColor, fontSize: 12)),
                    ],
                  ),
                ),
              )),

              const SizedBox(height: 20),

              // 4. Totals
              GlassContainer(
                opacity: 0.1,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Total Amount", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text("₦${widget.order.totalAmount.toStringAsFixed(0)}", style: const TextStyle(color: AppTheme.secondaryColor, fontSize: 22, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, {bool isSmall = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white54, size: 16),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: Colors.white, fontSize: isSmall ? 13 : 14))),
        ],
      ),
    );
  }
}
