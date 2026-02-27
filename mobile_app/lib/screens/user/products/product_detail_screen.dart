import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Added
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart'; 
import 'package:clotheline_core/clotheline_core.dart'; // [NEW]
import 'package:clotheline_core/clotheline_core.dart'; // [NEW]
import 'package:clotheline_core/clotheline_core.dart'; 
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'submit_review_screen.dart';
import '../../../utils/add_to_cart_animation.dart';
import 'store_cart_screen.dart';
import 'package:clotheline_core/clotheline_core.dart';
import '../../../widgets/fullscreen_gallery.dart';
import '../../../widgets/custom_cached_image.dart';
import 'package:clotheline_customer/widgets/glass/LaundryGlassBackground.dart';
import 'package:clotheline_customer/widgets/glass/UnifiedGlassHeader.dart';
import 'package:clotheline_core/clotheline_core.dart';
import '../../../widgets/products/SalesBanner.dart'; // [NEW] 

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
  
  // Review Logic Fields
  List<ReviewModel> _reviews = [];
  bool _isEligibleToReview = false;
  String? _eligibleOrderId;
  bool _isReviewLoading = true;

  // Keys for Animation
  final GlobalKey _cartKey = GlobalKey();
  final GlobalKey _addBtnKey = GlobalKey();

  void _showFullDescription(BuildContext context, Color textColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text("Product Details", style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  widget.product.description,
                  style: TextStyle(color: textColor.withOpacity(0.8), height: 1.6, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchAppContent();
    _fetchReviewsAndEligibility();
    if (widget.product.variants.isNotEmpty) {
       _selectedVariant = widget.product.variants.first;
    }
  }

  Future<void> _fetchReviewsAndEligibility() async {
    setState(() => _isReviewLoading = true);
    
    try {
      final reviewService = Provider.of<ReviewService>(context, listen: false);
      final orderService = Provider.of<OrderService>(context, listen: false);

      // 1. Fetch Reviews
      final reviews = await reviewService.getProductReviews(widget.product.id);
      
      // 2. Check Eligibility (User must have a completed order with this product)
      // Ensure orders are fetched
      if (orderService.orders.isEmpty) {
        await orderService.fetchOrders();
      }

      bool eligible = false;
      String? orderId;

      for (var order in orderService.orders) {
        if (order.status == OrderStatus.Completed) {
          final hasProduct = order.items.any((item) => item.itemType == 'Product' && item.itemId == widget.product.id);
          if (hasProduct) {
            // Check if already reviewed for this order
            final alreadyReviewed = reviews.any((r) => r.orderId == order.id);
            if (!alreadyReviewed) {
              eligible = true;
              orderId = order.id;
              break;
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _reviews = reviews;
          _isEligibleToReview = eligible;
          _eligibleOrderId = orderId;
          _isReviewLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching reviews/eligibility: $e");
      if (mounted) setState(() => _isReviewLoading = false);
    }
  }

  Future<void> _fetchAppContent() async {
    final content = await _contentService.getAppContent();
    if (mounted) setState(() => _appContent = content);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF101010) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    final cartService = CartService();
    final storeService = StoreService(); // For recommended products
    final favoritesService = Provider.of<FavoritesService>(context); // [NEW]
    final isFav = favoritesService.isFavorite(widget.product.id); // [NEW]

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: LaundryGlassBackground(
        child: ListenableBuilder(
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
                     backgroundColor: Colors.transparent,
                     elevation: 0,
                     automaticallyImplyLeading: false, // Use UnifiedGlassHeader instead
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
                           ),
                         ],
                       ),
                     ),
                   ),
                   
                   SliverToBoxAdapter(
                     child: Padding(
                       padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 20.0),
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                            if (widget.product.detailBanner != null && widget.product.detailBanner!.isEnabled) ...[
                              const SizedBox(height: 10),
                              SalesBanner(config: widget.product.detailBanner!, mode: SalesBannerMode.flat),
                              const SizedBox(height: 10),
                            ],
                            _buildDeliveryAssurance(),
                           // 1. Title (Expandable)
                           _buildExpandableTitle(textColor),
                           const SizedBox(height: 6),

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
                            GestureDetector(
                               onTap: () => _showFullDescription(context, textColor),
                               child: Text(
                                 widget.product.description.isEmpty ? "No description available." : widget.product.description,
                                 maxLines: 5,
                                 overflow: TextOverflow.ellipsis,
                                 style: TextStyle(color: textColor.withOpacity(0.8), height: 1.5),
                               ),
                            ),
                            if (widget.product.description.length > 200)
                              GestureDetector(
                                onTap: () => _showFullDescription(context, textColor),
                                child: const Padding(
                                  padding: EdgeInsets.only(top: 8.0),
                                  child: Text("Read More", style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
                                ),
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

              // 3. Header
              Positioned(
                top: 0, left: 0, right: 0,
                child: UnifiedGlassHeader(
                  isDark: true, // Product details look better with a dark header overlay on images
                  title: const SizedBox.shrink(),
                  onBack: () => Navigator.pop(context),
                  actions: [
                    IconButton(
                      icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : Colors.white),
                      onPressed: () => favoritesService.toggleFavorite(widget.product.id),
                    ),
                    Stack(
                       clipBehavior: Clip.none,
                       children: [
                         IconButton(
                           key: _cartKey,
                           icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                           onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StoreCartScreen())),
                         ),
                         if (cartService.storeItems.isNotEmpty)
                           Positioned(
                             right: 4, top: 4,
                             child: Container(
                               padding: const EdgeInsets.all(4),
                               decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                               child: Text("${cartService.storeItems.fold(0, (s, i) => s + i.quantity)}", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white))
                             )
                           )
                       ],
                    ),
                  ],
                ),
              ),
            ],
          );
        }
      ),
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
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: textColor),
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
     final bool isOOS = widget.product.isOutOfStock || widget.product.stockLevel <= 0;
     int stock = widget.product.stockLevel;
     
     if (isOOS) {
       return Container(
         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
         decoration: BoxDecoration(
           border: Border.all(color: Colors.red),
           borderRadius: BorderRadius.circular(4),
           color: Colors.red.withOpacity(0.1)
         ),
         child: const Text("OUT OF STOCK", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
       );
     }

     return Container(
       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
       decoration: BoxDecoration(
         border: Border.all(color: Colors.deepOrange),
         borderRadius: BorderRadius.circular(4),
         color: Colors.deepOrange.withOpacity(0.1)
       ),
       child: Text("$stock in stock currently", style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 13)),
     );
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
                Text(widget.product.rating.toStringAsFixed(1), style: TextStyle(color: textColor, fontSize: 28, fontWeight: FontWeight.bold)),
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
            if (_isEligibleToReview && _eligibleOrderId != null)
              ElevatedButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SubmitReviewScreen(
                      productId: widget.product.id,
                      productName: widget.product.name,
                      productImageUrl: widget.product.imagePath,
                      orderId: _eligibleOrderId!,
                    ),
                  ),
                );
                  _fetchReviewsAndEligibility(); // Refresh after submitting
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  foregroundColor: AppTheme.primaryColor,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text("Write a Review", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              )
            else
              Icon(Icons.chevron_right, color: textColor.withOpacity(0.5))
          ],
        ),
        const SizedBox(height: 16),
        
        if (_isReviewLoading)
          const Center(child: CircularProgressIndicator())
        else if (_reviews.isEmpty)
          const Text("No reviews yet. Be the first!", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
        else
          ..._reviews.take(3).map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(r.userName, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                    const Spacer(),
                    Text("${r.createdAt.day}/${r.createdAt.month}/${r.createdAt.year}", style: const TextStyle(color: Colors.grey, fontSize: 10))
                  ],
                ),
                Row(children: List.generate(5, (i) => Icon(i < r.rating ? Icons.star : Icons.star_border, color: Colors.amber, size: 12))),
                if (r.comment != null && r.comment!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _ExpandableReviewText(text: r.comment!, color: textColor),
                ],
                if (r.images.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: r.images.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenGallery(
                                imageUrls: r.images,
                                initialIndex: index,
                              )));
                            },
                            child: Container(
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: CustomCachedImage(
                                imageUrl: r.images[index],
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                borderRadius: 0, // Parent clips
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
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
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
            ),
            child: CustomCachedImage(
              imageUrl: url, 
              fit: BoxFit.cover, 
              borderRadius: 0, // card clips
            ),
          ),
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
                        child: Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: CustomCachedImage(
                            imageUrl: p.imagePath, 
                            fit: BoxFit.cover, 
                            borderRadius: 0, // card clips
                          ),
                        ),
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
                    if (cartItem.quantity > 1) {
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
      final bool isOOS = widget.product.isOutOfStock || widget.product.stockLevel <= 0;
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          key: _addBtnKey, 
          style: ElevatedButton.styleFrom(
            backgroundColor: isOOS ? Colors.grey : const Color(0xFFFF5722),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
          onPressed: isOOS ? null : () {
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
          child: Text(isOOS ? "OUT OF STOCK" : "Add to Cart", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      );
    }
  }

  Widget _buildDeliveryAssurance() {
     final da = _appContent?.deliveryAssurance;
     if (da == null || !da.active) return const SizedBox.shrink();

     IconData iconData = Icons.local_shipping;
     Color iconColor = Colors.green; // Default Green (Van)

     if (da.icon == 'bike') {
       iconData = Icons.motorcycle;
       iconColor = Colors.red;
     }
     if (da.icon == 'clock') {
       iconData = Icons.access_time;
       iconColor = Colors.purple;
     }

     return Padding(
       padding: const EdgeInsets.only(bottom: 4.0), // Reduced Gap
       child: Row(
         crossAxisAlignment: CrossAxisAlignment.center,
         children: [
            _DrivingIcon(icon: iconData, color: iconColor), 
            const SizedBox(width: 8),
            Expanded(child: _parseRichText(da.text))
         ],
       ),
     );
  }

  Widget _parseRichText(String text) {
     List<InlineSpan> spans = [];
     RegExp exp = RegExp(r'\[(.*?)\]');
     Iterable<RegExpMatch> matches = exp.allMatches(text);
     
     int lastIndex = 0;
     for (final match in matches) {
        if (match.start > lastIndex) {
           spans.add(TextSpan(text: text.substring(lastIndex, match.start)));
        }
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline, 
          baseline: TextBaseline.alphabetic,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(3)
            ),
            child: Text(match.group(1)!, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)), 
          )
        ));
        lastIndex = match.end;
     }
     if (lastIndex < text.length) {
        spans.add(TextSpan(text: text.substring(lastIndex)));
     }
     
     return RichText(
       text: TextSpan(
         style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, fontSize: 14),
         children: spans
       )
     );
  }
}

class _DrivingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  const _DrivingIcon({required this.icon, required this.color});

  @override
  State<_DrivingIcon> createState() => _DrivingIconState();
}

class _DrivingIconState extends State<_DrivingIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _horizontalAnimation;
  late Animation<double> _verticalAnimation;
  late Animation<double> _linesAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat();
    
    _horizontalAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: -2.0, end: 2.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 2.0, end: -2.0), weight: 50),
    ]).animate(_controller);

    _verticalAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -3.0).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
      TweenSequenceItem(tween: Tween(begin: -3.0, end: 0.0).chain(CurveTween(curve: Curves.bounceOut)), weight: 70),
    ]).animate(_controller);

    _linesAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Speed Lines (Now look like they move through/behind)
            SizedBox(
              width: 24,
              height: 18,
              child: Stack(
                children: [
                  Positioned(
                    left: (1.0 - _linesAnimation.value) * 15,
                    top: 4,
                    child: _buildSpeedLine(12, 0.4 * _linesAnimation.value),
                  ),
                  Positioned(
                    left: (1.0 - _linesAnimation.value) * 20,
                    top: 8,
                    child: _buildSpeedLine(18, 0.7 * _linesAnimation.value),
                  ),
                  Positioned(
                    left: (1.0 - _linesAnimation.value) * 10,
                    top: 12,
                    child: _buildSpeedLine(8, 0.3 * _linesAnimation.value),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 2),
            Transform.translate(
              offset: Offset(_horizontalAnimation.value, _verticalAnimation.value),
              child: Icon(widget.icon, color: widget.color, size: 18),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSpeedLine(double width, double opacity) {
    return Container(
      width: width,
      height: 1.5,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [widget.color.withOpacity(0), widget.color.withOpacity(opacity)],
        ),
      ),
    );
  }
}

class _ExpandableReviewText extends StatefulWidget {
  final String text;
  final Color color;

  const _ExpandableReviewText({required this.text, required this.color});

  @override
  State<_ExpandableReviewText> createState() => _ExpandableReviewTextState();
}

class _ExpandableReviewTextState extends State<_ExpandableReviewText> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          maxLines: _isExpanded ? null : 2,
          overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: TextStyle(color: widget.color.withOpacity(0.8), fontSize: 13),
        ),
        if (widget.text.length > 80) // Simple heuristic or use TextPainter for precision
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                _isExpanded ? "Read Less" : "Read More",
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

