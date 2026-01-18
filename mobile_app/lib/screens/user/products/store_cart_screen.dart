import 'package:flutter/material.dart';
import '../../../models/store_product.dart';
import '../../../services/cart_service.dart';
import '../../../utils/currency_formatter.dart';
import 'package:laundry_app/theme/app_theme.dart';
import 'store_checkout_screen.dart';
import 'package:provider/provider.dart';
import '../../../providers/branch_provider.dart';

class StoreCartScreen extends StatelessWidget {
  const StoreCartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cartService = CartService();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Consumer<BranchProvider>(
          builder: (context, branchProvider, _) {
            final branchName = branchProvider.selectedBranch?.name ?? "Global";
            return Text("Cart · $branchName", 
              style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 18)
            );
          }
        ),
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
                  Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey.withOpacity(0.3)),
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
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ...cartService.storeItems.map((item) => 
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildCartItem(context, item, isDark, cartService),
                      )
                    ),
                    const SizedBox(height: 10),
                    // Promo Code Section
                    _buildPromoSection(context, cartService, isDark),
                  ],
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

  Widget _buildPromoSection(BuildContext context, CartService service, bool isDark) {
    final promoController = TextEditingController();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_offer_outlined, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text("Promotions", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          if (service.appliedPromotion != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3))
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "${service.appliedPromotion!['code']} applied (-${CurrencyFormatter.format(service.discountAmount)})",
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)
                    )
                  ),
                  InkWell(
                    onTap: () => service.removePromo(),
                    child: const Icon(Icons.close, size: 18, color: Colors.grey)
                  )
                ],
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: promoController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      hintText: "Enter Promo Code",
                      hintStyle: TextStyle(color: Colors.grey),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () async {
                    if (promoController.text.isEmpty) return;
                    final error = await service.applyPromoCode(promoController.text);
                    if (error != null) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                    } else {
                      promoController.clear();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Promotion Applied!"), backgroundColor: Colors.green));
                    }
                  },
                  child: const Text("Apply"),
                )
              ],
            )
        ],
      ),
    );
  }

  // ... (Keep _buildCartItem as is, assume unchanged or include if simpler)
  // Actually, keeping _buildCartItem is tricky if I overwrite the whole build method.
  // I must include _buildCartItem in the Replacement if I'm replacing the class body partially logic.
  // Wait, I am replacing `build`, `_buildPromoSection` (new), and `_buildCheckoutBar`.
  // I need to ensure `_buildCartItem` and others remain.
  // I'll target specific blocks or replace the whole file content?
  // Replacing everything from `build` downwards seems safest to ensure structural integrity if I have the whole file.
  // I have the whole file in lines 1-213.

  Widget _buildCartItem(BuildContext context, StoreCartItem item, bool isDark, CartService service) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 20, right: 8),
            child: Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 22),
          ),
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: item.product.imageUrls.isNotEmpty
                  ? DecorationImage(image: NetworkImage(item.product.imageUrls.first), fit: BoxFit.cover)
                  : null,
              color: item.product.imageUrls.isEmpty ? Colors.grey[800] : null,
              border: Border.all(color: Colors.grey.withOpacity(0.1))
            ),
          ),
          const SizedBox(width: 12),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(CurrencyFormatter.format(item.price), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF5722), fontSize: 16)),
                    Container(
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.withOpacity(0.3)), borderRadius: BorderRadius.circular(4)),
                      child: Row(
                        children: [
                          _qtyButton(Icons.remove, () {
                            if (item.quantity > 1) service.updateStoreItemQuantity(item, item.quantity - 1);
                            else service.removeStoreItem(item);
                          }, isDark),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text("${item.quantity}", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black))),
                          _qtyButton(Icons.add, () => service.updateStoreItemQuantity(item, item.quantity + 1), isDark),
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
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
        ]
      ),
      child: SafeArea(
        child: Column(
          children: [
             // Breakdown
             _row("Subtotal", CurrencyFormatter.format(service.storeTotalAmount), isDark),
             if (service.discountAmount > 0)
                _row("Discount", "-${CurrencyFormatter.format(service.discountAmount)}", isDark, color: Colors.green),
             _row("Tax (${service.taxRate}%)", CurrencyFormatter.format(service.storeTaxAmount), isDark),
             const Divider(height: 20),
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 const Text("Total", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                 Text(CurrencyFormatter.format(service.storeTotalAmount + service.storeTaxAmount - service.discountAmount), style: const TextStyle(color: Color(0xFFFF5722), fontWeight: FontWeight.bold, fontSize: 20)),
               ],
             ),
             const SizedBox(height: 16),
             SizedBox(
               width: double.infinity,
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

  Widget _row(String label, String value, bool isDark, {Color? color}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
            Text(value, style: TextStyle(color: color ?? (isDark ? Colors.white : Colors.black), fontWeight: FontWeight.bold)),
          ],
        ),
      );
  }
}
