import 'package:flutter/material.dart';
import 'package:laundry_app/services/content_service.dart';
import 'package:laundry_app/models/app_content_model.dart';
import '../../../models/store_product.dart';
import '../../../services/cart_service.dart'; 
import '../../../utils/add_to_cart_animation.dart';
import 'store_cart_screen.dart';
import 'package:liquid_glass_ui/liquid_glass_dropdown.dart';
import '../../../utils/currency_formatter.dart';
import '../../../widgets/fullscreen_gallery.dart';

class ProductDetailScreen extends StatefulWidget {
  final StoreProduct product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  bool _isFavorite = false;
  ProductVariant? _selectedVariant;
  final ContentService _contentService = ContentService();
  AppContentModel? _appContent;
  int _currentImageIndex = 0;
  
  // Keys for Animation
  final GlobalKey _cartKey = GlobalKey();
  final GlobalKey _addBtnKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _fetchAppContent();
    if (widget.product.variants.isNotEmpty) {
       _selectedVariant = widget.product.variants.first;
    }
  }

  Future<void> _fetchAppContent() async {
    final content = await _contentService.getAppContent();
    if (mounted) setState(() => _appContent = content);
  }

  @override
  Widget build(BuildContext context) {
    const priceColor = Color(0xFFFF5722);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF101010) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    final cartService = CartService();

    return Scaffold(
      backgroundColor: bgColor,
      body: ListenableBuilder(
        listenable: cartService,
        builder: (context, _) {
          StoreCartItem? cartItem;
          try {
             if (widget.product.variants.isNotEmpty) {
                cartItem = cartService.storeItems.firstWhere((i) => i.product.id == widget.product.id && i.variant?.id == _selectedVariant?.id);
             } else {
                cartItem = cartService.storeItems.firstWhere((i) => i.product.id == widget.product.id);
             }
          } catch (e) {
            cartItem = null;
          }

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                   SliverAppBar(
                     expandedHeight: 400, 
                     pinned: true,
                     backgroundColor: bgColor,
                     leading: IconButton(
                       icon: const CircleAvatar(backgroundColor: Colors.white24, child: Icon(Icons.arrow_back, color: Colors.black)),
                       onPressed: () => Navigator.pop(context),
                     ),
                     actions: [
                        CircleAvatar(
                          backgroundColor: Colors.white24,
                          child: IconButton(
                            icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border, color: _isFavorite ? Colors.red : Colors.black),
                            onPressed: () => setState(() => _isFavorite = !_isFavorite),
                          ),
                        ),
                        const SizedBox(width: 10),
                        
                        Stack(
                          children: [
                            CircleAvatar(
                              key: _cartKey,
                              backgroundColor: Colors.white24,
                              child: IconButton(
                                icon: const Icon(Icons.shopping_cart_outlined, color: Colors.black),
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StoreCartScreen())),
                              ),
                            ),
                            if (cartService.storeItems.isNotEmpty)
                              Positioned(right: 0, top: 0, child: CircleAvatar(radius: 8, backgroundColor: Colors.red, child: Text("${cartService.storeItems.fold(0, (s, i) => s + i.quantity)}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white))))
                          ],
                        ),
                        const SizedBox(width: 10),
                     ],
                     flexibleSpace: FlexibleSpaceBar(
                       background: Stack(
                         children: [
                           PageView.builder(
                             itemCount: widget.product.imageUrls.isNotEmpty ? widget.product.imageUrls.length : 1,
                             onPageChanged: (index) => setState(() => _currentImageIndex = index),
                             itemBuilder: (context, index) {
                               String img = widget.product.imagePath;
                               if (widget.product.imageUrls.isNotEmpty) img = widget.product.imageUrls[index];

                               return GestureDetector(
                                 onTap: () {
                                   Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenGallery(
                                     imageUrls: widget.product.imageUrls.isNotEmpty ? widget.product.imageUrls : [widget.product.imagePath],
                                     initialIndex: index,
                                   )));
                                 },
                                 child: img.startsWith('http') 
                                   ? Image.network(img, fit: BoxFit.cover, errorBuilder: (_,__,___) => Image.asset('assets/images/service_laundry.png', fit: BoxFit.cover)) 
                                   : Image.asset(img, fit: BoxFit.cover),
                               );
                             },
                           ),
                           Positioned(
                             bottom: 16,
                             right: 16,
                             child: Container(
                               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                               decoration: BoxDecoration(
                                 color: Colors.black54,
                                 borderRadius: BorderRadius.circular(20),
                               ),
                               child: Text(
                                 "${_currentImageIndex + 1}/${widget.product.imageUrls.isNotEmpty ? widget.product.imageUrls.length : 1}",
                                 style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                               ),
                             ),
                           )
                         ],
                       ),
                     ),
                   ),
                   
                   SliverToBoxAdapter(
                     child: Padding(
                       padding: const EdgeInsets.all(20.0),
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           // 1. Title (After Images)
                           Text(
                             widget.product.name, 
                             maxLines: 2,
                             overflow: TextOverflow.ellipsis,
                             style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textColor, height: 1.2)
                           ),
                           const SizedBox(height: 12),

                           // 2. Brand Tag
                           Container(
                             padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                             decoration: BoxDecoration(
                               color: const Color(0xFF5D4037), // Brownish
                               borderRadius: BorderRadius.circular(8),
                               boxShadow: [BoxShadow(color: Colors.brown.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))],
                             ),
                             child: Text(
                               _appContent?.brandText ?? "🏅 Official Brand: Clotheline ~ Quality Assurance",
                               style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                             ),
                           ),
                           const SizedBox(height: 12),

                           // 3. Sold Count
                           Row(
                             children: [
                               const Text("🔥", style: TextStyle(fontSize: 18)),
                               const SizedBox(width: 6),
                               Text("${widget.product.soldCount} sold recently", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600, fontSize: 13)),
                             ],
                           ),
                           const SizedBox(height: 16),

                            // 4. Price (Big & Bold)
                            Builder(
                              builder: (context) {
                                double currentPrice = _selectedVariant?.price ?? widget.product.price;
                                double currentOriginalPrice = _selectedVariant?.originalPrice ?? widget.product.originalPrice;
                                
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    const Text("₦", style: TextStyle(color: Color(0xFFFF5722), fontSize: 20, fontWeight: FontWeight.bold)),
                                    Text(
                                      CurrencyFormatter.format(currentPrice).replaceAll('₦', ''), 
                                      style: const TextStyle(color: Color(0xFFFF5722), fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: -1)
                                    ),
                                    const SizedBox(width: 8),
                                    if (currentPrice < currentOriginalPrice)
                                      Text(
                                        CurrencyFormatter.format(currentOriginalPrice), 
                                        style: const TextStyle(color: Colors.grey, fontSize: 16, decoration: TextDecoration.lineThrough, fontWeight: FontWeight.w500)
                                      ),
                                  ],
                                );
                              }
                            ),
                           
                           // Saved Amount Badge
                           if (widget.product.savedAmount > 0)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFE0B2), 
                                  borderRadius: BorderRadius.circular(4)
                                ),
                                child: Text("Saved ${CurrencyFormatter.format(widget.product.savedAmount)} extra", style: const TextStyle(color: Color(0xFFE65100), fontSize: 12, fontWeight: FontWeight.bold)),
                              ),

                           // 5. Variations
                           if (widget.product.variants.isNotEmpty) ...[
                             const SizedBox(height: 24),
                             Text("Select Variation", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                             const SizedBox(height: 10),
                             LiquidGlassDropdown<ProductVariant>(
                               value: _selectedVariant ?? widget.product.variants.first, // Ensure non-null
                               isDark: isDark,
                               items: widget.product.variants.map((v) {
                                 return DropdownMenuItem(
                                   value: v,
                                   child: Text(v.name),
                                 );
                               }).toList(),
                               onChanged: (v) {
                                 setState(() => _selectedVariant = v);
                               },
                             ),
                           ],
                           
                           const SizedBox(height: 24),

                           // 6. Praise Card
                           Container(
                             width: double.infinity,
                             padding: const EdgeInsets.all(12),
                             decoration: BoxDecoration(
                               gradient: const LinearGradient(colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)]), // Light Green Gradient
                               borderRadius: BorderRadius.circular(12),
                               border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                             ),
                             child: Row(
                               children: [
                                 const Icon(Icons.emoji_events, color: Colors.green, size: 20),
                                 const SizedBox(width: 8),
                                 Expanded(
                                   child: RichText(
                                     text: TextSpan(
                                       style: const TextStyle(color: Color(0xFF1B5E20), fontSize: 13),
                                       children: [
                                         const TextSpan(text: "🏆 #13 Best selling ", style: TextStyle(fontWeight: FontWeight.bold)),
                                         const TextSpan(text: "in "),
                                         TextSpan(text: "${widget.product.category}", style: const TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                                       ]
                                     ),
                                   ),
                                 )
                               ],
                             ),
                           ),
                           
                           const SizedBox(height: 16),

                           // 7. Free Shipping
                           Row(
                             children: [
                               Container(
                                 padding: const EdgeInsets.all(8),
                                 decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), shape: BoxShape.circle),
                                 child: const Icon(Icons.local_shipping_outlined, color: Colors.orange, size: 20),
                               ),
                               const SizedBox(width: 12),
                               Expanded(
                                 child: Column(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                     Text("Free Shipping", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                                     const SizedBox(height: 2),
                                     Text("For orders above ₦20,000", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                   ],
                                 ),
                               ),
                               const Icon(Icons.chevron_right, color: Colors.grey),
                             ],
                           ),
                           
                           const SizedBox(height: 100),
                         ],
                       ),
                     ),
                   )
                ],
              ),
              
              // Bottom Action Bar (Unified)
              Positioned(
                bottom: 0, 
                left: 0, 
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                  decoration: BoxDecoration(
                    color: bgColor,
                    border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.1))),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))]
                  ),
                  child: _buildActionButtons(context, cartService, cartItem),
                ),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, CartService service, StoreCartItem? cartItem) {
    if (cartItem != null) {
      return Row(
        children: [
          // Qty Selector
          Container(
            height: 48,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () {
                    if (cartItem!.quantity > 1) {
                      service.updateStoreItemQuantity(cartItem, cartItem.quantity - 1);
                    } else {
                      service.removeStoreItem(cartItem);
                    }
                  },
                ),
                Text("${cartItem.quantity}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => service.updateStoreItemQuantity(cartItem, cartItem.quantity + 1),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5722),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StoreCartScreen())),
              child: const Text("Go to Cart", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      );
    } else {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          key: _addBtnKey, 
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF5722),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
          onPressed: () {
             AddToCartAnimation.run(context, _addBtnKey, _cartKey, () {
               // Animation Done
             });
             
             final item = StoreCartItem(
               product: widget.product,
               variant: _selectedVariant,
               quantity: 1
             );
             service.addStoreItem(item);
          },
          child: const Text("Add to Cart", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      );
    }
  }
}
