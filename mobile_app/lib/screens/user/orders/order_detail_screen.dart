import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../theme/app_theme.dart';
import '../../../../models/order_model.dart';
import '../../../../utils/currency_formatter.dart';
import '../../../../widgets/glass/LaundryGlassCard.dart';
import '../../../../services/payment_service.dart';
import '../../../../services/receipt_service.dart';
import '../../../../utils/toast_utils.dart';
import '../chat/chat_screen.dart';
import 'package:provider/provider.dart';
import '../../../../services/notification_service.dart';
import 'package:laundry_app/widgets/glass/LaundryGlassBackground.dart';
import '../products/submit_review_screen.dart';
import '../../../../services/order_service.dart';
import '../../../widgets/dialogs/guest_login_dialog.dart';
import '../../../services/auth_service.dart';
import '../../../../services/whatsapp_service.dart'; // [NEW]

class OrderDetailScreen extends StatefulWidget {
  final OrderModel order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  @override
  void initState() {
    super.initState();
    // [Auto-Read Policy] Mark specific order notifications read
    Future.microtask(() => 
      Provider.of<NotificationService>(context, listen: false).markReadByEntity(widget.order.id, type: 'order')
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order; // Access widget.order
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white70 : Colors.black54;

    return LaundryGlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent, // Global Background Consistency
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text("Order Details", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
          centerTitle: true,
            systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent, // [FIX] Ensure status bar is transparent
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          ),
        ),
        body: SingleChildScrollView(
            physics: const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics()), // [FIX] Prevent overscroll void
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 70, left: 20, right: 20, bottom: 20),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (order.status == OrderStatus.PendingUserConfirmation && order.feeAdjustment != null)
                _buildAdjustmentBanner(order, isDark, textColor),
              
              const SizedBox(height: 10),

              // Status Card
              LaundryGlassCard(
                opacity: isDark ? 0.12 : 0.05,
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
                child: LaundryGlassCard(
                  opacity: isDark ? 0.12 : 0.05,
                  padding: const EdgeInsets.all(12), // [TIGHTER]
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(CurrencyFormatter.format(item.price * item.quantity), 
                            style: TextStyle(color: textColor, fontWeight: FontWeight.bold)
                          ),
                          if (order.status == OrderStatus.Completed && item.itemType == 'Product')
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SubmitReviewScreen(
                                        productId: item.itemId,
                                        productName: item.name,
                                        orderId: order.id,
                                      ),
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  foregroundColor: AppTheme.primaryColor,
                                ),
                                child: const Text("Write a Review", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              )),

              const SizedBox(height: 25),
              Text("Payment Summary", style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 15),

              const SizedBox(height: 15),

              LaundryGlassCard(
                opacity: isDark ? 0.12 : 0.6, 
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                     _buildTextRow("Status", order.paymentStatus.name, 
                      (order.paymentStatus == PaymentStatus.Paid) ? Colors.green : Colors.orange, isBold: true),
                    const Divider(height: 20),
                    _buildSummaryRow("Subtotal", order.subtotal, textColor),
                    if (order.taxAmount > 0)
                      _buildSummaryRow("VAT (${order.taxRate}%)", order.taxAmount, textColor),
                    if (order.deliveryFee > 0)
                      _buildSummaryRow("Delivery Fee", order.deliveryFee, textColor),
                    if (order.pickupFee > 0)
                      _buildSummaryRow("Pickup Fee", order.pickupFee, textColor),
                    if (order.discountAmount > 0 || order.storeDiscount > 0)
                      _buildSummaryRow("Discount", -(order.discountAmount + order.storeDiscount), Colors.green),
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
                      final auth = context.read<AuthService>();
                      if (auth.isGuest) {
                        showDialog(
                          context: context,
                          builder: (ctx) => const GuestLoginDialog(
                            message: "Please sign in or create an account to pay for this order.",
                          ),
                        );
                        return;
                      }

                      // Trigger Payment (Revised Flow)
                      final paymentService = PaymentService();
                      final email = order.guestName != null ? "guest@clotheline.com" : "user@clotheline.com"; 
                      
                      try {
                        ToastUtils.show(context, "Initializing Payment...", type: ToastType.info);
                        
                        // 1. Initialize (Retry Flow with Order ID)
                        final initData = await paymentService.initializePayment({
                          'orderId': order.id,
                          'guestInfo': { 'email': email } // Fallback email logic
                        });
                        
                        if (initData != null && context.mounted) {
                           final url = initData['authorization_url'];
                           final ref = initData['reference'];
                           
                           // 2. Open WebView
                           await paymentService.openPaymentWebView(context, url, ref);
                           
                           // 3. Verify
                           if (context.mounted) {
                             ToastUtils.show(context, "Verifying Payment...", type: ToastType.info);
                             final verifyResult = await paymentService.verifyAndCreateOrder(ref);
                             
                             if (verifyResult != null && verifyResult['status'] == 'success') {
                                 if (context.mounted) {
                                   ToastUtils.show(context, "Payment Successful!", type: ToastType.success);
                                   Navigator.pop(context); // Refresh
                                 }
                             } else {
                                 if (context.mounted) ToastUtils.show(context, "Payment Verification Failed", type: ToastType.error);
                             }
                           }
                        }
                      } catch (e) {
                         if (context.mounted) ToastUtils.show(context, "Payment Error: $e", type: ToastType.error);
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
                       await ReceiptService.printReceiptFromOrder(order);
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
                child: Column(
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.help_outline),
                      label: const Text("Need Help with this Order?"),
                      onPressed: () {
                         Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(orderId: order.id)));
                      },
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.whatsapp, color: Colors.green),
                      label: const Text("Contact Support via WhatsApp", style: TextStyle(color: Colors.green)),
                      onPressed: () {
                         WhatsAppService.contactSupport(orderNumber: order.id);
                      },
                    ),
                  ],
                ),
              )
            ],
          ), // Column
        ), // SingleChildScrollView
      ),
    ); // LaundryGlassBackground
  }

  Widget _buildAdjustmentBanner(OrderModel order, bool isDark, Color textColor) {
    if (order.feeAdjustment == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.15),
        border: Border.all(color: Colors.orange.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Delivery Fee Updated",
                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "An additional fee of ${CurrencyFormatter.format(order.feeAdjustment!.amount)} is required for this delivery. Your order is currently paused awaiting your confirmation.",
            style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 13),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _payAdditionalFee(order),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text("Pay ₦${order.feeAdjustment!.amount.toStringAsFixed(0)} Now"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _confirmPayOnDelivery(order),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Pay on Delivery"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _payAdditionalFee(OrderModel order) async {
    final paymentService = PaymentService();
    
    try {
      ToastUtils.show(context, "Initializing Additional Payment...", type: ToastType.info);
      
      final initData = await paymentService.initializePayment({
        'orderId': order.id,
        'scope': 'adjustment',
      });
      
      if (initData != null && context.mounted) {
        final url = initData['authorization_url'];
        final ref = initData['reference'];
        
        await paymentService.openPaymentWebView(context, url, ref);
        
        if (context.mounted) {
          ToastUtils.show(context, "Verifying Payment...", type: ToastType.info);
          final verifyResult = await paymentService.verifyAndCreateOrder(ref);
          
          if (verifyResult != null && verifyResult['status'] == 'success') {
            if (context.mounted) {
              await Provider.of<OrderService>(context, listen: false).fetchOrders();
              if (context.mounted) {
                ToastUtils.show(context, "Payment Successful! Order resumed.", type: ToastType.success);
                Navigator.pop(context); // Refresh
              }
            }
          }
        }
      }
    } catch (e) {
      if (context.mounted) ToastUtils.show(context, "Payment Error: $e", type: ToastType.error);
    }
  }

  Future<void> _confirmPayOnDelivery(OrderModel order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Selection"),
        content: Text("You will pay the extra cost of ${CurrencyFormatter.format(order.feeAdjustment!.amount)} to the rider upon delivery. Proceed?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("PROCEED")),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final success = await Provider.of<OrderService>(context, listen: false)
          .confirmFeeAdjustment(order.id, 'PayOnDelivery');
      
      if (success && context.mounted) {
        ToastUtils.show(context, "Selection confirmed. Order resumed.", type: ToastType.success);
        Navigator.pop(context); // Refresh
      }
    }
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
      case OrderStatus.Refunded: return Colors.pinkAccent;
      case OrderStatus.PendingUserConfirmation: return Colors.orange;
    }
  }

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.New: return Icons.new_releases;
      case OrderStatus.InProgress: return Icons.local_laundry_service;
      case OrderStatus.Ready: return Icons.check_circle_outline;
      case OrderStatus.Completed: return Icons.done_all;
      case OrderStatus.Cancelled: return Icons.cancel;
      case OrderStatus.Refunded: return Icons.money_off; 
      case OrderStatus.PendingUserConfirmation: return Icons.pending_actions;
    }
  }
}
