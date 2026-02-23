import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/currency_formatter.dart';
import '../../../models/booking_models.dart'; // [FIX] Added missing import
import '../../../services/cart_service.dart';
// Will import CheckoutScreen later
import 'checkout_screen.dart'; 
import 'package:laundry_app/widgets/glass/LaundryGlassBackground.dart';
import 'package:laundry_app/widgets/glass/UnifiedGlassHeader.dart';
import '../../../widgets/dialogs/guest_login_dialog.dart';
import '../../../services/auth_service.dart';
import 'package:provider/provider.dart';

class MyBucketScreen extends StatelessWidget {
  final List<CartItem> cart;

  const MyBucketScreen({super.key, required this.cart});

  void _proceedToCheckout(BuildContext context) {
    final auth = context.read<AuthService>();
    if (auth.isGuest) {
      showDialog(
        context: context,
        builder: (ctx) => const GuestLoginDialog(
          message: "Please sign in or create an account to proceed with your laundry booking.",
        ),
      );
      return;
    }

    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => const CheckoutScreen(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white70 : Colors.black54;

    final cartService = CartService(); // [Restored]
    
    // [Recalculate for visual consistency with CartService Gross Logic]
    double grossSubtotal = cart.fold(0, (sum, item) => sum + (item.item.basePrice * (item.serviceType?.priceMultiplier ?? 1.0) * item.quantity));
    
    // Calculate Discounts locally for the view if needed, or rely on service if cart matches
    Map<String, double> discounts = {};
    for (var item in cart) {
      if (item.discountPercentage > 0) {
         double base = item.item.basePrice * (item.serviceType?.priceMultiplier ?? 1.0) * item.quantity;
         double d = base * (item.discountPercentage / 100);
         String key = "Discount (${item.serviceType?.name ?? 'Generic'})";
         discounts[key] = (discounts[key] ?? 0) + d;
      }
    }
    double totalDiscount = discounts.values.fold(0, (sum, v) => sum + v);
    double netSubtotal = grossSubtotal - totalDiscount;
    if (netSubtotal < 0) netSubtotal = 0;
    
    double tax = netSubtotal * (cartService.taxRate / 100); // Tax on Net
    double grandTotal = netSubtotal + tax;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: LaundryGlassBackground(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 100, left: 20, right: 20, bottom: 20),
                    itemCount: cart.length,
                    separatorBuilder: (ctx, i) => Divider(color: isDark ? Colors.white10 : Colors.grey.shade200),
                    itemBuilder: (context, index) {
                      final item = cart[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Easy Quantity Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                "${item.quantity}x",
                                style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.item.name, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(item.serviceType?.name ?? "Regular Service", style: TextStyle(color: secondaryTextColor, fontSize: 14)),
                                ],
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(item.totalPrice),
                              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    
                Container(
                  padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).padding.bottom + 20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                    border: Border(
                      top: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                        blurRadius: 15,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Subtotal", style: TextStyle(color: secondaryTextColor, fontSize: 16)),
                          Text(CurrencyFormatter.format(grossSubtotal), style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w500)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // [NEW] Itemized Discounts (Category Based)
                      ...discounts.entries.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(e.key, style: const TextStyle(color: Colors.green, fontSize: 16)),
                            Text("-${CurrencyFormatter.format(e.value)}", style: const TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      )),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("VAT (${cartService.taxRate}%)", style: TextStyle(color: secondaryTextColor, fontSize: 16)),
                          Text(CurrencyFormatter.format(tax), style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w500)),
                        ],
                      ),
                      const Divider(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Total Amount", style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(CurrencyFormatter.format(grandTotal), style: const TextStyle(color: AppTheme.primaryColor, fontSize: 24, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          onPressed: () => _proceedToCheckout(context),
                          child: const Text("CONFIRM", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),

            // Header
            Positioned(
              top: 0, left: 0, right: 0,
              child: UnifiedGlassHeader(
                isDark: isDark,
                title: Text("My Bucket", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
                onBack: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
