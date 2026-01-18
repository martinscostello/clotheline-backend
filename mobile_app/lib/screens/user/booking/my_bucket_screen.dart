import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/branch_provider.dart';
import '../../../utils/currency_formatter.dart';
import '../../../models/booking_models.dart'; // [FIX] Added missing import
import '../../../services/cart_service.dart';
// Will import CheckoutScreen later
import 'checkout_screen.dart'; 
import 'package:flutter/services.dart';

class MyBucketScreen extends StatelessWidget {
  final List<CartItem> cart;

  const MyBucketScreen({super.key, required this.cart});

  void _proceedToCheckout(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => const CheckoutScreen(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white70 : Colors.black54;

    final cartService = CartService();
    double subtotal = cart.fold(0, (sum, item) => sum + item.totalPrice);
    double tax = subtotal * (cartService.taxRate / 100);
    double grandTotal = subtotal + tax;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("My Bucket", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
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
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
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
                            Text(item.serviceType.name, style: TextStyle(color: secondaryTextColor, fontSize: 14)),
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
          
          // Bottom Area
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              boxShadow: [
                 BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))
              ]
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Subtotal", style: TextStyle(color: secondaryTextColor, fontSize: 16)),
                    Text(CurrencyFormatter.format(subtotal), style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 8),
                // [NEW] Itemized Discounts
                ...cartService.laundryDiscounts.entries.map((e) => Padding(
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 5,
                    ),
                    onPressed: () => _proceedToCheckout(context),
                    child: const Text("CONFIRM", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
