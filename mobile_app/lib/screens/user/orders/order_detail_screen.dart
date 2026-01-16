import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../theme/app_theme.dart';
import '../../../../models/order_model.dart';
import '../../../../utils/currency_formatter.dart';
import '../../../../widgets/glass/GlassContainer.dart';
import '../../../../services/payment_service.dart';
import '../../../../services/receipt_service.dart';

class OrderDetailScreen extends StatelessWidget {
  final OrderModel order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("Order Details", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            GlassContainer(
              opacity: isDark ? 0.1 : 0.05,
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order.status).withOpacity(0.1),
                      shape: BoxShape.circle
                    ),
                    child: Icon(_getStatusIcon(order.status), color: _getStatusColor(order.status)),
                  ),
                  const SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Order #${order.id.substring(order.id.length - 6).toUpperCase()}", 
                        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)
                      ),
                      Text(order.status.name.toUpperCase(), 
                        style: TextStyle(color: _getStatusColor(order.status), fontWeight: FontWeight.bold, fontSize: 12)
                      ),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 25),
            
            Text("Items Ordered", style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 15),

            // Items List
            ...order.items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isDark ? [] : [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
                  ]
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)
                      ),
                      child: Text("${item.quantity}x", style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                          Text(item.serviceType ?? 'Standard', style: TextStyle(color: secondaryTextColor, fontSize: 12)),
                        ],
                      ),
                    ),
                    Text(CurrencyFormatter.format(item.price * item.quantity), 
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold)
                    ),
                  ],
                ),
              ),
            )),

            const SizedBox(height: 25),
            Text("Payment Summary", style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 15),

            const SizedBox(height: 15),

            GlassContainer(
              opacity: isDark ? 0.1 : 0.05, 
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                   _buildTextRow("Status", order.paymentStatus.name, 
                    (order.paymentStatus == PaymentStatus.Paid) ? Colors.green : Colors.orange, isBold: true),
                  const Divider(height: 20),
                  _buildSummaryRow("Subtotal", order.totalAmount, textColor),
                  // We could add delivery fee here if tracked separately in future
                  const Divider(height: 30),
                  _buildSummaryRow("Total", order.totalAmount, AppTheme.primaryColor, isBold: true, isTotal: true),
                ],
              ),
            ),
            
            const SizedBox(height: 30),

            if (order.status != OrderStatus.Cancelled && order.paymentStatus == PaymentStatus.Pending)
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () async {
                    // Trigger Payment
                    final paymentService = PaymentService();
                    // Need email. If guestInfo, use it. If user, likely in session but not in simple OrderModel yet.
                    // Fallback to a placeholder or ask user. For MVP, we use guestInfo or default.
                    final email = order.guestName != null ? "guest@clotheline.com" : "user@clotheline.com"; 
                    
                    bool success = await paymentService.processPayment(context, orderId: order.id, email: email);
                    
                    if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment Successful!")));
                        Navigator.pop(context); // Pop to refresh (or implement auto-refresh)
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text("PAY NOW", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),

            if (order.paymentStatus == PaymentStatus.Paid)
               SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton.icon(
                  onPressed: () async {
                     final receiptService = ReceiptService();
                     await receiptService.downloadReceipt(order);
                  },
                  icon: Icon(Icons.download, color: textColor),
                  label: Text("DOWNLOAD RECEIPT", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
               ),

            const SizedBox(height: 20),
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.help_outline),
                label: const Text("Need Help with this Order?"),
                onPressed: () {
                  // TODO: Navigate to Chat with context
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, Color color, {bool isBold = false, bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: color, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: isTotal ? 18 : 14)),
        Text(CurrencyFormatter.format(amount), style: TextStyle(color: color, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: isTotal ? 18 : 14)),
      ],
    );
  }

  Widget _buildTextRow(String label, String value, Color color, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: color, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
        Text(value, style: TextStyle(color: color, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
      ],
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.New: 
      case OrderStatus.InProgress: return Colors.orange;
      case OrderStatus.Ready: 
      case OrderStatus.Completed: return Colors.green;
      case OrderStatus.Cancelled: return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.New: return Icons.new_releases;
      case OrderStatus.InProgress: return Icons.local_laundry_service;
      case OrderStatus.Ready: return Icons.check_circle_outline;
      case OrderStatus.Completed: return Icons.done_all;
      case OrderStatus.Cancelled: return Icons.cancel;
      default: return Icons.help_outline;
    }
  }
}
