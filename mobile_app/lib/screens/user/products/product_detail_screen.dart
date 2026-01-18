import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Added
import 'package:laundry_app/services/content_service.dart';
import 'package:laundry_app/models/app_content_model.dart';
import '../../../models/store_product.dart';
import '../../../services/cart_service.dart'; 
import '../../../services/store_service.dart'; // [NEW]
import '../../../services/favorites_service.dart'; // [NEW]
import '../../../utils/add_to_cart_animation.dart';
import 'store_cart_screen.dart';
import 'package:liquid_glass_ui/liquid_glass_dropdown.dart';
import '../../../utils/currency_formatter.dart';
import '../../../widgets/fullscreen_gallery.dart';
import '../../../widgets/custom_cached_image.dart'; // Added Import

class ProductDetailScreen extends StatefulWidget {
  final StoreProduct product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  // bool _isFavorite = false; // REMOVED
  ProductVariant? _selectedVariant;
  final ContentService _contentService = ContentService();
  AppContentModel? _appContent;
  int _currentImageIndex = 0;
  bool _isTitleExpanded = false;
  
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
    final storeService = StoreService(); // For recommended products
    final favoritesService = Provider.of<FavoritesService>(context); // [NEW]
    final isFav = favoritesService.isFavorite(widget.product.id); // [NEW]

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
                   // Image Carousel (Top)
                   SliverAppBar(
                     expandedHeight: 400, 
                     pinned: true,
                     backgroundColor: bgColor,
                     leading: IconButton(
                       icon: const CircleAvatar(backgroundColor: Colors.black26, child: Icon(Icons.arrow_back, color: Colors.white)),
                       onPressed: () => Navigator.pop(context),
                     ),
                     actions: [
                        CircleAvatar(
                          backgroundColor: Colors.black26,
                          child: IconButton(
                            icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : Colors.white),
                            onPressed: () => favoritesService.toggleFavorite(widget.product.id),
                          ),
                        ),
                        const SizedBox(width: 10),
                        
                        Stack(
                          children: [
                            CircleAvatar(
                              key: _cartKey,
                              backgroundColor: Colors.black26,
                              child: IconButton(
                                icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
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
                                 child: CustomCachedImage(
                                     imageUrl: img,
                                     fit: BoxFit.cover,
                                     borderRadius: 0,
                                 ),
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
                       padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20),
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           // 1. Title (Expandable)
                           _buildExpandableTitle(textColor),
                           const SizedBox(height: 12),

                           // 2. Brand Tag
                           Row(
                             children: [
                               Container(
                                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                 decoration: BoxDecoration(
                                   color: Colors.grey.withOpacity(0.1),
                                   borderRadius: BorderRadius.circular(4),
                                   border: Border.all(color: Colors.grey.withOpacity(0.3))
                                 ),
                                 child: Text(
                                   widget.product.brand.isNotEmpty ? widget.product.brand.toUpperCase() : "GENERIC",
                                   style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.bold),
                                 ),
                               ),
                             ],
                           ),
                           const SizedBox(height: 12),

                           // 3. Sold Count
                           Text("🔥 ${widget.product.soldCount} sold", style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
                           const SizedBox(height: 8),

                            // 4. Price Row
                            Builder(
                              builder: (context) {
                                double currentPrice = _selectedVariant?.price ?? widget.product.price;
                                double currentOriginalPrice = _selectedVariant?.originalPrice ?? widget.product.originalPrice;
                                bool hasDiscount = currentOriginalPrice > currentPrice;
                                
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (hasDiscount) ...[
                                       Text(
                                        CurrencyFormatter.format(currentOriginalPrice), 
                                        style: const TextStyle(color: Colors.grey, fontSize: 14, decoration: TextDecoration.lineThrough)
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    
                                    Text(
                                      CurrencyFormatter.format(currentPrice), 
                                      style: const TextStyle(color: Color(0xFFFF5722), fontSize: 26, fontWeight: FontWeight.w900)
                                    ),

                                    if (hasDiscount) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        "${((currentOriginalPrice - currentPrice) / currentOriginalPrice * 100).round()}% OFF", 
                                        style: const TextStyle(color: Color(0xFFFF5722), fontSize: 14, fontWeight: FontWeight.bold)
                                      ),
                                    ]
                                  ],
                                ),
                                if (hasDiscount)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        "Saved ${CurrencyFormatter.format(currentOriginalPrice - currentPrice)} extra",
                                        style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                              }
                            ),
                           const SizedBox(height: 12),

                           // 5. Stock Indicator
                           _buildStockIndicator(),
                           
                           // 6. Variations
                           if (widget.product.variants.isNotEmpty) ...[
                             const SizedBox(height: 20),
                             Text("Select Variation", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15)),
                             const SizedBox(height: 10),
                             Wrap(
                               spacing: 10,
                               runSpacing: 10,
                               children: widget.product.variants.map((v) {
                                  bool isSelected = _selectedVariant?.id == v.id;
                                  return GestureDetector(
                                    onTap: () => setState(() => _selectedVariant = v),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFFFF5722).withOpacity(0.1) : Colors.transparent,
                                        border: Border.all(color: isSelected ? const Color(0xFFFF5722) : Colors.grey.withOpacity(0.4)),
                                        borderRadius: BorderRadius.circular(20)
                                      ),
                                      child: Text(v.name, style: TextStyle(
                                        color: isSelected ? const Color(0xFFFF5722) : textColor,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                                      )),
                                    ),
                                  );
                               }).toList(),
                             )
                           ],
                           
                           const SizedBox(height: 24),

                           // 7. Best Selling Banner
                           Container(
                             width: double.infinity,
                             padding: const EdgeInsets.all(12),
                             decoration: BoxDecoration(
                               color: const Color(0xFFFFF3E0), // Orange tint
                               borderRadius: BorderRadius.circular(8),
                             ),
                             child: Row(
                               children: [
                                 const Icon(Icons.emoji_events, color: Colors.orange, size: 20),
                                 const SizedBox(width: 8),
                                 Expanded(
                                   child: RichText(
                                     text: TextSpan(
                                       style: const TextStyle(color: Colors.black87, fontSize: 13),
                                       children: [
                                         const TextSpan(text: "Best selling in ", style: TextStyle(fontWeight: FontWeight.bold)),
                                         TextSpan(text: widget.product.category, style: const TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                                       ]
                                     ),
                                   ),
                                 )
                               ],
                             ),
                           ),
                           const SizedBox(height: 16),

                           // 8. Free Shipping
                           _buildFreeShipping(),
                           const SizedBox(height: 16),

                           // 9. Trustee Banner
                           Container(
                             width: double.infinity,
                             padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                             decoration: BoxDecoration(
                               border: Border.all(color: Colors.green.withOpacity(0.3)),
                               borderRadius: BorderRadius.circular(4),
                             ),
                             child: const Row(
                               mainAxisAlignment: MainAxisAlignment.center,
                               children: [
                                 Icon(Icons.verified_user_outlined, color: Colors.green, size: 20),
                                 SizedBox(width: 8),
                                 Text("🛡️ Safe Payments ~ Secure Privacy", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                               ],
                             ),
                           ),
                           const SizedBox(height: 24),

                           // 10. Reviews
                           _buildReviewSection(textColor),
                           const Divider(height: 40),

                           // 11. Product Details
                           Text("Product Details", style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                           const SizedBox(height: 12),
                           Text(
                             widget.product.description.isEmpty ? "No description available." : widget.product.description,
                             style: TextStyle(color: textColor.withOpacity(0.8), height: 1.5),
                           ),
                           const SizedBox(height: 24),

                           // 12. Large Images
                           _buildLargeImages(),
                           const SizedBox(height: 30),

                           // 13. Recommended Products
                           _buildRecommendedProducts(storeService, textColor),

                           const SizedBox(height: 100),
                         ],
                       ),
                     ),
                   )
                ],
              ),
              
              // Bottom Action Bar
              Positioned(
                bottom: 0, 
                left: 0, 
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                  decoration: BoxDecoration(
                    color: bgColor,
                    border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]
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

  Widget _buildExpandableTitle(Color textColor) {
    return GestureDetector(
      onTap: () => setState(() => _isTitleExpanded = !_isTitleExpanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.product.name,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textColor),
            maxLines: _isTitleExpanded ? null : 2,
            overflow: _isTitleExpanded ? null : TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(
                _isTitleExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: Colors.grey,
                size: 20,
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStockIndicator() {
     int stock = widget.product.stockLevel;
     if (stock <= 5) {
       return Container(
         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
         decoration: BoxDecoration(
           border: Border.all(color: Colors.deepOrange),
           borderRadius: BorderRadius.circular(4),
           color: Colors.deepOrange.withOpacity(0.1)
         ),
         child: const Text("[Almost sold out]", style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 12)),
       );
     }
     return Text("$stock in stock currently", style: const TextStyle(color: Colors.grey, fontSize: 13));
  }

  Widget _buildFreeShipping() {
    double threshold = _appContent?.freeShippingThreshold ?? 25000;
    return Row(
     children: [
        const Icon(Icons.local_shipping_outlined, color: Colors.grey, size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Free Shipping", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text("Above ${CurrencyFormatter.format(threshold)}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
     ],
   );
  }

  Widget _buildReviewSection(Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text("${widget.product.rating.toStringAsFixed(1)}", style: TextStyle(color: textColor, fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: List.generate(5, (i) => Icon(i < widget.product.rating.round() ? Icons.star : Icons.star_border, color: Colors.amber, size: 16))),
                    Text("(${widget.product.reviewCount} Reviews)", style: const TextStyle(color: Colors.grey, fontSize: 12))
                  ],
                )
              ],
            ),
            Icon(Icons.chevron_right, color: textColor.withOpacity(0.5))
          ],
        ),
        const SizedBox(height: 16),
        // Customer Reviews List
        if (widget.product.reviews.isEmpty)
           const Text("No reviews yet. Be the first!", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
        else
          ...widget.product.reviews.take(2).map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(r.userName, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                    const Spacer(),
                    Text("${r.date.day}/${r.date.month}/${r.date.year}", style: const TextStyle(color: Colors.grey, fontSize: 10))
                  ],
                ),
                Row(children: List.generate(5, (i) => Icon(i < r.rating.round() ? Icons.star : Icons.star_border, color: Colors.amber, size: 12))),
                const SizedBox(height: 4),
                Text(r.comment, style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 13))
              ],
            ),
          ))
      ],
    );
  }

  Widget _buildLargeImages() {
    return Column(
      children: widget.product.imageUrls.map((url) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: AspectRatio(
          aspectRatio: 1,
          child: CustomCachedImage(imageUrl: url, fit: BoxFit.cover, borderRadius: 8),
        ),
      )).toList(),
    );
  }

  Widget _buildRecommendedProducts(StoreService service, Color textColor) {
    // We need to fetch products, filter by category
    // Since this is UI sync, we rely on cache in StoreService
    final sameCategory = service.products.where((p) => p.category == widget.product.category && p.id != widget.product.id).toList();
    if (sameCategory.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Text("Recommended Products", style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
         const SizedBox(height: 12),
         SingleChildScrollView(
           scrollDirection: Axis.horizontal,
           child: Row(
             children: sameCategory.map((p) => GestureDetector(
               onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(product: p))),
               child: Container(
                 width: 140,
                 margin: const EdgeInsets.only(right: 12),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: CustomCachedImage(imageUrl: p.imagePath, fit: BoxFit.cover, borderRadius: 8),
                      ),
                      const SizedBox(height: 6),
                      Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                      Text(CurrencyFormatter.format(p.price), style: const TextStyle(color: Color(0xFFFF5722), fontWeight: FontWeight.bold))
                   ],
                 ),
               ),
             )).toList(),
           ),
         )
      ],
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
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
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
