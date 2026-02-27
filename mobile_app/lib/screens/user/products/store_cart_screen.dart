import 'package:flutter/material.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'store_checkout_screen.dart';
import 'package:provider/provider.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_customer/widgets/glass/LaundryGlassBackground.dart';
import 'package:clotheline_customer/widgets/glass/UnifiedGlassHeader.dart';
import '../../../widgets/dialogs/guest_login_dialog.dart';
import 'package:clotheline_core/clotheline_core.dart';

class StoreCartScreen extends StatelessWidget {
  const StoreCartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cartService = Provider.of<CartService>(context); // Listen to provider

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: LaundryGlassBackground(
        child: Stack(
          children: [
            // 1. Content
            if (cartService.storeItems.isEmpty) 
               Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey.withOpacity(0.3)),
                    const SizedBox(height: 20),
                    const Text("Your cart is empty", style: TextStyle(color: Colors.grey, fontSize: 16)),
                  ],
                ),
              )
            else
              Column(
                children: [
                  // Cart Items List
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 100, left: 16, right: 16, bottom: 20),
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
              ),

            // 2. Header
            Positioned(
              top: 0, left: 0, right: 0,
              child: UnifiedGlassHeader(
                isDark: isDark,
                title: Consumer<BranchProvider>(
                  builder: (context, branchProvider, _) {
                    final branchName = branchProvider.selectedBranch?.name ?? "Global";
                    return Text("Cart · $branchName", 
                      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 18)
                    );
                  }
                ),
                onBack: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoSection(BuildContext context, CartService service, bool isDark) {
    // Avoid re-creating controller on rebuilds if possible or just use localized state.
    // Since this is Stateless, controller will recreate.
    // Ideally we convert to StatefulWidget or use a hook.
    // For now, I'll use a local variable inside the method but logic implies input loss on rebuild.
    // I should convert to Stateful or use a persistent controller.
    // I'll make the whole screen stateless but use a Hook or simple Consumer.
    // Wait, simple fix: `TextEditingController` inside `build` is bad.
    // Let's rely on standard Flutter behavior: if rebuild happens, text might be lost unless I hoist it.
    // Since `CartService` notifies listeners, keyboard might dismiss.
    // I will convert `StoreCartScreen` to `StatefulWidget` to hold controller.
    return const _PromoSection();
  }
  
  // Refactor buildCheckoutBar and others to be accessible or copy them into StatefulWidgetState.
  // Actually, I'll rewrite the whole class as StatefulWidget.
  
  Widget _buildCheckoutBar(BuildContext context, CartService service, bool isDark) {
    // Use Store Total + Tax - Discount
    // Simplification: Discount applies to total.
    double total = service.storeTotalAmount + service.storeTaxAmount - service.discountAmount;
    if (total < 0) total = 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, -5))
        ]
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
             _row("Subtotal", CurrencyFormatter.format(service.storeTotalAmount), isDark),
             if (service.discountAmount > 0)
                _row("Discount", "-${CurrencyFormatter.format(service.discountAmount)}", isDark, color: Colors.green),
             _row("Tax (${service.taxRate}%)", CurrencyFormatter.format(service.storeTaxAmount), isDark),
             const Divider(height: 20),
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Text("Total", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : Colors.black)),
                 Text(CurrencyFormatter.format(total), style: const TextStyle(color: Color(0xFFFF5722), fontWeight: FontWeight.bold, fontSize: 20)),
               ],
             ),
             const SizedBox(height: 16),
             SizedBox(
               width: double.infinity,
               child: ElevatedButton(
                 style: ElevatedButton.styleFrom(
                   backgroundColor: const Color(0xFFFF5722),
                   foregroundColor: Colors.white,
                   padding: const EdgeInsets.symmetric(vertical: 14),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), 
                   elevation: 0,
                 ),
                 onPressed: () {
                   if (service.storeItems.isEmpty) return;
                   
                   final auth = context.read<AuthService>();
                   if (auth.isGuest) {
                     showDialog(
                       context: context,
                       builder: (ctx) => const GuestLoginDialog(
                         message: "Please sign in or create an account to proceed with your store purchase.",
                       ),
                     );
                     return;
                   }

                   Navigator.of(context).push(MaterialPageRoute(
                     builder: (context) => const StoreCheckoutScreen(),
                   ));
                 },
                 child: const Text("Checkout Now", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
               ),
             ),
             SizedBox(height: MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom / 2 : 0),
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
          const Padding(
            padding: EdgeInsets.only(top: 20, right: 8),
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
                      child: const Icon(Icons.close, size: 18, color: Colors.grey),
                    )
                  ],
                ),
                if (item.variant != null)
                  Text(item.variant!.name, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown, 
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Text(CurrencyFormatter.format(item.price), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF5722), fontSize: 16)),
                                if (item.product.originalPrice > item.price) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    CurrencyFormatter.format(item.product.originalPrice),
                                    style: const TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (item.product.savedAmount > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                "Saved ${CurrencyFormatter.format(item.product.savedAmount)}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.withOpacity(0.3)), borderRadius: BorderRadius.circular(4)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _qtyButton(Icons.remove, () {
                            if (item.quantity > 1) {
                              service.updateStoreItemQuantity(item, item.quantity - 1);
                            } else {
                              service.removeStoreItem(item);
                            }
                          }, isDark, service, item),
                          Container(
                             constraints: const BoxConstraints(minWidth: 20),
                             padding: const EdgeInsets.symmetric(horizontal: 8), 
                             alignment: Alignment.center,
                             child: Text("${item.quantity}", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black))
                          ),
                          _qtyButton(Icons.add, () => service.updateStoreItemQuantity(item, item.quantity + 1), isDark, service, item),
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

  Widget _qtyButton(IconData icon, VoidCallback onTap, bool isDark, CartService service, StoreCartItem item) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 16, color: isDark ? Colors.white70 : Colors.black54),
      ),
    );
  }
}

class _PromoSection extends StatefulWidget {
  const _PromoSection();

  @override
  State<_PromoSection> createState() => _PromoSectionState();
}

class _PromoSectionState extends State<_PromoSection> {
  final TextEditingController _promoController = TextEditingController();

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final service = Provider.of<CartService>(context);

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
              const Icon(Icons.local_offer_outlined, color: AppTheme.primaryColor, size: 20),
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
                  const Icon(Icons.check_circle, size: 16, color: Colors.green),
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
                    controller: _promoController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      hintText: "Enter Promo Code",
                      hintStyle: const TextStyle(color: Colors.grey),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                  onPressed: () async {
                    if (_promoController.text.isEmpty) return;
                    FocusScope.of(context).unfocus();
                    final error = await service.applyPromoCode(_promoController.text);
                    if (error != null) {
                      if(mounted) ToastUtils.show(context, error, type: ToastType.error);
                    } else {
                      _promoController.clear();
                      if(mounted) ToastUtils.show(context, "Promotion Applied!", type: ToastType.success);
                    }
                  },
                  child: const Text("Apply", style: TextStyle(color: Colors.black)),
                )
              ],
            )
        ],
      ),
    );
  }
}
