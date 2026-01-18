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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white70 : Colors.black54;
    final glassOpacity = isDark ? 0.1 : 0.05;
    
    // Calculate Logistics Fees
    double deliveryFee = widget.logisticsData['deliveryFee'] ?? 0.0;
    double pickupFee = widget.logisticsData['pickupFee'] ?? 0.0;
    
    // Calculate Unified Financials
    double subtotal = cart.subtotal;
    // double discount = cart.discount; // If we want to show discount later
    double tax = cart.taxAmount;
    double total = cart.totalAmount + deliveryFee + pickupFee;

    Widget content = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 100, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Laundry Items Section
          if (cart.items.isNotEmpty) ...[
            Text("Laundry Items", style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            GlassContainer(
              opacity: glassOpacity,
              padding: const EdgeInsets.all(16),
              color: isDark ? null : Colors.black.withOpacity(0.05), // Subtle bg for light mode
              child: Column(
                children: cart.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text("${item.quantity}x ${item.item.name}", style: TextStyle(color: textColor))),
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
            Text("Store Items", style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            GlassContainer(
              opacity: glassOpacity,
              padding: const EdgeInsets.all(16),
              color: isDark ? null : Colors.black.withOpacity(0.05),
              child: Column(
                children: cart.storeItems.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text("${item.quantity}x ${item.product.name}", style: TextStyle(color: textColor))),
                      Text(CurrencyFormatter.format(item.totalPrice), style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // 3. Logistics Section
          Text("Logistics", style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          GlassContainer(
            opacity: glassOpacity,
            padding: const EdgeInsets.all(16),
            color: isDark ? null : Colors.black.withOpacity(0.05),
            child: Column(
              children: [
                if (pickupFee > 0)
                  _buildRow("Pickup Fee", pickupFee, textColor),
                if (deliveryFee > 0)
                  _buildRow("Delivery Fee", deliveryFee, textColor),
                if (pickupFee == 0 && deliveryFee == 0)
                   Text("Drop-off / Pickup at Branch (No Fee)", style: TextStyle(color: secondaryTextColor)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 4. Financial Breakdown
          Text("Payment Breakdown", style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          GlassContainer(
            opacity: isDark ? 0.15 : 0.08,
            padding: const EdgeInsets.all(16),
            color: isDark ? null : Colors.black.withOpacity(0.05),
            child: Column(
              children: [
                 _buildRow("Subtotal", subtotal, textColor),
                 const SizedBox(height: 5),
                 // [NEW] Itemized Laundry Discounts
                 ...cart.laundryDiscounts.entries.map((e) => Padding(
                   padding: const EdgeInsets.only(bottom: 5.0),
                   child: Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Text(e.key, style: const TextStyle(color: Colors.green, fontSize: 13)),
                       Text("-${CurrencyFormatter.format(e.value)}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                     ],
                   ),
                 )),
                 _buildRow("VAT (${cart.taxRate}%)", tax, textColor),
                 Divider(color: isDark ? Colors.white24 : Colors.black12, height: 20),
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Text("Total", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
                     Text(CurrencyFormatter.format(total), style: TextStyle(color: isDark ? AppTheme.primaryColor : Colors.green[700], fontWeight: FontWeight.bold, fontSize: 18)),
                   ],
                 )
              ],
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Order Summary", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: textColor),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background: Liquid only in Dark Mode
          if (isDark) const Positioned.fill(child: LiquidBackground(child: SizedBox())),
          
          // Content
          content,
          
          // Bottom Action Bar
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.black.withOpacity(0.9) : Colors.white.withOpacity(0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                   BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -4))
                ]
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
                       backgroundColor: isDark ? AppTheme.primaryColor : Colors.black,
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                       disabledBackgroundColor: Colors.grey,
                     ),
                     child: _isProcessing
                       ? const CircularProgressIndicator(color: Colors.white)
                       : Text("PAY ${CurrencyFormatter.format(total)}", style: TextStyle(color: isDark ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                   ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRow(String label, double amount, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: textColor.withOpacity(0.8))),
        Text(CurrencyFormatter.format(amount), style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
