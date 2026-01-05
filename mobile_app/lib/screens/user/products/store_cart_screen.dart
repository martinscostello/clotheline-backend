import 'package:flutter/material.dart';
import '../../../models/store_product.dart';
import '../../../services/cart_service.dart';
import '../../../utils/currency_formatter.dart';
import 'package:laundry_app/theme/app_theme.dart';
import 'store_checkout_screen.dart';

class StoreCartScreen extends StatelessWidget {
  const StoreCartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cartService = CartService();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text("Shopping Cart (${cartService.storeItems.length})", style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: ListenableBuilder(
        listenable: cartService,
        builder: (context, _) {
          if (cartService.storeItems.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey.withValues(alpha: 0.3)),
                  const SizedBox(height: 20),
                  Text("Your cart is empty", style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Cart Items List
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: cartService.storeItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final item = cartService.storeItems[index];
                    return _buildCartItem(context, item, isDark, cartService);
                  },
                ),
              ),

              // Bottom Checkout Bar
              _buildCheckoutBar(context, cartService, isDark),
            ],
          );
        }
      ),
    );
  }

  Widget _buildCartItem(BuildContext context, StoreCartItem item, bool isDark, CartService service) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        // boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: Offset(0, 4))]
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checkbox (Mock for now, assumes all selected)
          Padding(
            padding: const EdgeInsets.only(top: 20, right: 8),
            child: Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 22),
          ),
          
          // Image
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(image: AssetImage(item.product.imagePath), fit: BoxFit.cover),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.1))
            ),
          ),
          const SizedBox(width: 12),
          
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(item.product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87))),
                    InkWell(
                      onTap: () => service.removeStoreItem(item),
                      child: Icon(Icons.close, size: 18, color: Colors.grey),
                    )
                  ],
                ),
                if (item.variant != null)
                  Text(item.variant!.name, style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 8),
                
                // Price & Qty Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                            Text(CurrencyFormatter.format(item.price), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF5722), fontSize: 16)),
                    
                    // Qty Selector
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          _qtyButton(Icons.remove, () {
                            if (item.quantity > 1) {
                              service.updateStoreItemQuantity(item, item.quantity - 1);
                            } else {
                              service.removeStoreItem(item);
                            }
                          }, isDark),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text("${item.quantity}", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                          ),
                          _qtyButton(Icons.add, () {
                             service.updateStoreItemQuantity(item, item.quantity + 1);
                          }, isDark),
                        ],
                      ),
                    )
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 16, color: isDark ? Colors.white70 : Colors.black54),
      ),
    );
  }

  Widget _buildCheckoutBar(BuildContext context, CartService service, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))
        ]
      ),
      child: SafeArea(
        child: Row(
          children: [
             Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               mainAxisSize: MainAxisSize.min,
               children: [
                 Text("Total:", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 12)),
                 Text(CurrencyFormatter.format(service.storeTotalAmount), style: const TextStyle(color: Color(0xFFFF5722), fontWeight: FontWeight.bold, fontSize: 20)),
               ],
             ),
             const SizedBox(width: 20),
             Expanded(
               child: ElevatedButton(
                 style: ElevatedButton.styleFrom(
                   backgroundColor: const Color(0xFFFF5722),
                   foregroundColor: Colors.white,
                   padding: const EdgeInsets.symmetric(vertical: 12),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                 ),
                 onPressed: () {
                   Navigator.of(context).push(MaterialPageRoute(
                     builder: (context) => const StoreCheckoutScreen(),
                   ));
                 },
                 child: const Text("Checkout", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
               ),
             )
          ],
        ),
      ),
    );
  }
}
