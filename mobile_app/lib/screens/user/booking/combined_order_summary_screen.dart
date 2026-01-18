import 'package:flutter/material.dart';
import 'package:laundry_app/theme/app_theme.dart';
import 'package:laundry_app/widgets/glass/LiquidBackground.dart';
import 'package:laundry_app/widgets/glass/GlassContainer.dart';
import 'package:provider/provider.dart';
import '../../../services/cart_service.dart'; // From task.md plan
import '../../../utils/currency_formatter.dart';
import '../../../services/payment_service.dart';

class CombinedOrderSummaryScreen extends StatefulWidget {
  final Map<String, dynamic> logisticsData;
  final Function(Map<String, dynamic>) onProceed;

  const CombinedOrderSummaryScreen({
    super.key,
    required this.logisticsData,
    required this.onProceed,
  });

  @override
  State<CombinedOrderSummaryScreen> createState() => _CombinedOrderSummaryScreenState();
}

class _CombinedOrderSummaryScreenState extends State<CombinedOrderSummaryScreen> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartService>(context);
    
    // Calculate Logistics Fees
    double deliveryFee = widget.logisticsData['deliveryFee'] ?? 0.0;
    double pickupFee = widget.logisticsData['pickupFee'] ?? 0.0;
    
    // Calculate Unified Financials
    double subtotal = cart.subtotal;
    double tax = cart.taxAmount;
    double total = cart.totalAmount + deliveryFee + pickupFee;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Order Summary", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
      ),
      body: LiquidBackground(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 100, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Laundry Items Section
                    if (cart.items.isNotEmpty) ...[
                      const Text("Laundry Items", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      GlassContainer(
                        opacity: 0.1,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: cart.items.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text("${item.quantity}x ${item.item.name}", style: const TextStyle(color: Colors.white))),
                                Text(CurrencyFormatter.format(item.totalPrice), style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          )).toList(),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // 2. Store Items Section
                    if (cart.storeItems.isNotEmpty) ...[
                      const Text("Store Items", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      GlassContainer(
                        opacity: 0.1,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: cart.storeItems.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text("${item.quantity}x ${item.product.name}", style: const TextStyle(color: Colors.white))),
                                Text(CurrencyFormatter.format(item.totalPrice), style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          )).toList(),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // 3. Logistics Section
                    const Text("Logistics", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    GlassContainer(
                      opacity: 0.1,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          if (pickupFee > 0)
                            _buildRow("Pickup Fee", pickupFee),
                          if (deliveryFee > 0)
                            _buildRow("Delivery Fee", deliveryFee),
                          if (pickupFee == 0 && deliveryFee == 0)
                             const Text("Drop-off / Pickup at Branch (No Fee)", style: TextStyle(color: Colors.white60)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 4. Financial Breakdown
                    const Text("Payment Breakdown", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    GlassContainer(
                      opacity: 0.15,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                           _buildRow("Subtotal", subtotal),
                           const SizedBox(height: 5),
                           _buildRow("VAT (${cart.taxRate}%)", tax),
                           const Divider(color: Colors.white24, height: 20),
                           Row(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: [
                               const Text("Total", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                               Text(CurrencyFormatter.format(total), style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 18)),
                             ],
                           )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SafeArea(
                child: SizedBox(
                   width: double.infinity,
                   height: 55,
                   child: ElevatedButton(
                     onPressed: _isProcessing ? null : () async {
                       setState(() => _isProcessing = true);
                       await widget.onProceed(widget.logisticsData); // Delegate back
                       if(mounted) setState(() => _isProcessing = false);
                     },
                     style: ElevatedButton.styleFrom(
                       backgroundColor: AppTheme.primaryColor,
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                     ),
                     child: _isProcessing
                       ? const CircularProgressIndicator(color: Colors.white)
                       : Text("PAY ${CurrencyFormatter.format(total)}", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                   ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        Text(CurrencyFormatter.format(amount), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
