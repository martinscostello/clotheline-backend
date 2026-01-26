import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:laundry_app/theme/app_theme.dart';
import 'package:laundry_app/widgets/glass/LaundryGlassBackground.dart';
import 'package:laundry_app/widgets/glass/UnifiedGlassHeader.dart';
import 'package:laundry_app/widgets/glass/GlassContainer.dart';
import 'package:provider/provider.dart';
import '../../../services/cart_service.dart'; // From task.md plan
import '../../../utils/currency_formatter.dart';
import '../../../providers/branch_provider.dart';

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
  final bool _isProcessing = false;

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

    Widget content = Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
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
                   Consumer<BranchProvider>(
                     builder: (context, branchProvider, _) {
                        final branch = branchProvider.selectedBranch;
                        final displayAddress = branch?.address ?? "Branch Office";
                        final displayPhone = branch?.phone ?? "";
                        return Column(
                          children: [
                            Text("Drop-off / Pickup at Office", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(displayAddress, style: TextStyle(color: secondaryTextColor, fontSize: 13), textAlign: TextAlign.center),
                            if (displayPhone.isNotEmpty)
                              Text("Tel: $displayPhone", style: TextStyle(color: secondaryTextColor, fontSize: 13)),
                          ],
                        );
                     }
                   ),
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
                 )).toList(),
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
    ),
  );

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: LaundryGlassBackground(
        child: Column(
          children: [
            // Header
            UnifiedGlassHeader(
              isDark: isDark,
              title: Text("Order Summary", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
              onBack: () => Navigator.pop(context),
            ),

            // Content
            content,
            
            // Bottom Area (No container)
            _buildBottomBar(isDark, total),
          ],
        ),
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

  Widget _buildBottomBar(bool isDark, double total) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 10, 24, MediaQuery.of(context).padding.bottom + 20),
      child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("TOTAL DUE", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12, fontWeight: FontWeight.bold)),
                      Text(CurrencyFormatter.format(total), style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: _isProcessing ? null : () => widget.onProceed(widget.logisticsData),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isProcessing 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Place Order", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        );
  }
}
