import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../../utils/currency_formatter.dart';
import '../../../services/store_service.dart';
import '../../../services/cart_service.dart';
import '../../../models/store_product.dart';
import 'product_detail_screen.dart';
import 'store_cart_screen.dart';
import 'package:laundry_app/services/content_service.dart';
import 'package:laundry_app/models/app_content_model.dart';
import '../../../widgets/custom_cached_image.dart'; 
import '../favorites_screen.dart'; 
import '../../../providers/branch_provider.dart'; // Corrected Path
import 'package:provider/provider.dart';
import '../../../utils/toast_utils.dart';
import 'package:laundry_app/widgets/glass/UnifiedGlassHeader.dart';
import 'package:laundry_app/widgets/glass/LaundryGlassCard.dart';
import 'package:laundry_app/theme/app_theme.dart';
import '../../../widgets/products/SalesBanner.dart'; // [NEW] 

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final StoreService _storeService = StoreService(); // Singleton
  final ContentService _contentService = ContentService();
  AppContentModel? _appContent;
  String _selectedCategory = "All";
  String _searchQuery = "";


  bool _isHydrated = false;

  @override
  void initState() {
    super.initState();
    _hydrateAndSync();
    
  }


  Future<void> _hydrateAndSync() async {
    final branchProvider = Provider.of<BranchProvider>(context, listen: false);
    final branchId = branchProvider.selectedBranch?.id;

    // 1. Load Content Cache (Branch Aware)
    await _contentService.loadFromCache(branchId: branchId).then((c) {
       if (mounted) setState(() => _appContent = c);
    });

    // 2. Load Product Cache (Branch Aware)
    await _storeService.loadFromCache(branchId: branchId);

    if (mounted) {
      setState(() => _isHydrated = true);
    }

    // 3. Silent Sync
    _performSilentSync();
  }
  
  Future<void> _performSilentSync() async {
     final branchProvider = Provider.of<BranchProvider>(context, listen: false);
     final branchId = branchProvider.selectedBranch?.id;

     _contentService.fetchFromApi(branchId: branchId).then((c) {
        if (mounted && c != null) setState(() => _appContent = c);
     });
     
     if (mounted) {
       _storeService.fetchFromApi(branchId: branchId);
     }
  }

  List<StoreProduct> get _filteredProducts {
    return _storeService.products.where((product) {
      final matchesCategory = _selectedCategory == "All" || product.category == _selectedCategory;
      final matchesSearch = product.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cartService = CartService();
    final bgColor = isDark ? const Color(0xFF101010) : const Color(0xFFF5F5F5);

    // HYDRATION GATE
    if (!_isHydrated) {
       return Scaffold(
         backgroundColor: bgColor,
         body: _buildSkeleton(isDark), 
       );
    }

    return Scaffold(
      backgroundColor: Colors.transparent, // Consistent Global Background
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _performSilentSync,
            color: AppTheme.primaryColor,
            backgroundColor: Colors.transparent, // [FIX] No dark background
            edgeOffset: 120, // Push refresh indicator down
            child: ListenableBuilder(
              listenable: _storeService,
              builder: (context, _) {
                final products = _filteredProducts;
                return CustomScrollView(
                  physics: const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics()), // [FIX] Prevent overscroll void
                  slivers: [
                    // Top Padding for Header
                    SliverPadding(padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 90)), // Reduced from 130

                    // 1. Sales Banner (Bigger)
                    Builder(
                      builder: (context) {
                        final ads = _appContent?.productAds.where((a) => a.active).toList() ?? [];
                        if (ads.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                        
                        return SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 0),
                            child: AspectRatio(
                              aspectRatio: 16/9,
                              child: CustomCachedImage(
                                imageUrl: ads.first.imageUrl,
                                fit: BoxFit.cover,
                                borderRadius: 0,
                              ),
                            ),
                          ),
                        );
                      }
                    ),

                    // 2. Categories Scrollable (MOVED HERE)
                    SliverToBoxAdapter(
                      child: _buildCategories(isDark),
                    ),

                    // 3. Trust/Guarantee Banner
                    Builder(
                      builder: (context) {
                        final ads = _appContent?.productAds.where((a) => a.active).toList() ?? [];
                        if (ads.length < 2) return const SliverToBoxAdapter(child: SizedBox.shrink());

                        return SliverToBoxAdapter(
                          child: Container(
                            height: 60,
                            margin: const EdgeInsets.only(bottom: 10),
                            child: CustomCachedImage(
                              imageUrl: ads[1].imageUrl,
                              fit: BoxFit.cover,
                              borderRadius: 0,
                            ),
                          ),
                        );
                      }
                    ),

                    // 4. Product Grid
                    if (products.isEmpty)
                       SliverFillRemaining(
                         child: Center(child: Text("No products found", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey))),
                       )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        sliver: SliverMasonryGrid.count(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childCount: products.length,
                          itemBuilder: (context, index) {
                            final product = products[index];
                            return _buildTemuCard(context, product, isDark);
                          },
                        ),
                      ),
                    
                    const SliverToBoxAdapter(child: SizedBox(height: 100)), // Bottom padding
                  ],
                );
              }
            ),
          ),

          // HEADER
          Positioned(
            top: 0, left: 0, right: 0,
            child: UnifiedGlassHeader(
              isDark: isDark,
              height: 90, // Standard height
              title: _buildSearchBar(isDark),
              actions: [
                 IconButton(
                   icon: Icon(Icons.favorite_border, color: isDark ? Colors.white : Colors.black87, size: 28),
                   padding: EdgeInsets.zero,
                   onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const FavoritesScreen())),
                 ),
                 ListenableBuilder(
                   listenable: cartService,
                   builder: (context, _) {
                     return Stack(
                       children: [
                         IconButton(
                           icon: Icon(Icons.shopping_cart_outlined, color: isDark ? Colors.white : Colors.black87, size: 28),
                           padding: EdgeInsets.zero,
                           onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const StoreCartScreen())),
                         ),
                         if (cartService.storeItems.isNotEmpty)
                           Positioned(
                             right: 4, top: 4,
                             child: Container(
                               padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                               decoration: const BoxDecoration(color: Color(0xFFFF5722), shape: BoxShape.circle),
                               constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                               child: Text(
                                 "${cartService.storeItems.fold(0, (sum, i) => sum + i.quantity)}", 
                                 textAlign: TextAlign.center,
                                 style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                               ),
                             ),
                           ),
                       ],
                     );
                   }
                 ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      height: 52, // [MATCHES Header Action Height]
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Center(
        child: TextField(
          controller: _searchController,
          textAlignVertical: TextAlignVertical.center, // [ALIGNS TEXT CENTRALLY]
          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14),
          onChanged: (val) {
            setState(() => _searchQuery = val);
          },
          decoration: InputDecoration(
            hintText: "Search products",
            hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
            prefixIcon: Icon(Icons.search, size: 20, color: isDark ? Colors.white54 : Colors.black45),
            border: InputBorder.none,
            isDense: true, // [CRITICAL for alignment]
            contentPadding: const EdgeInsets.symmetric(horizontal: 15),
          suffixIcon: _searchQuery.isNotEmpty 
            ? IconButton(
                icon: const Icon(Icons.close, size: 18), 
                onPressed: () { 
                   _searchController.clear();
                   setState(() => _searchQuery = "");
                }
              ) 
            : null,
          ),
        ),
      ),
    );
  }

  Widget _buildCategories(bool isDark) {
    return ListenableBuilder(
      listenable: _storeService,
      builder: (context, _) {
        return Container(
          // key: _filterKey, // [KEY] Category Filter (Removed)
          height: 50,
          color: Colors.transparent, // Transparent for Glass effect
          margin: const EdgeInsets.only(top: 10),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: _storeService.categories.length,
            itemBuilder: (context, index) {
              final cat = _storeService.categories[index];
              final isSelected = cat == _selectedCategory;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategory = cat;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 15),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        cat,
                        style: TextStyle(
                          color: isSelected ? (isDark ? Colors.white : Colors.red) : (isDark ? Colors.white54 : Colors.black54), // Active is Red (Temu)
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 15,
                        ),
                      ),
                      if (isSelected)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          height: 3,
                          width: 20,
                          decoration: BoxDecoration(
                            color: Colors.red, // Temu Red underline
                            borderRadius: BorderRadius.circular(2)
                          ),
                        )
                    ],
                  ),
                ),
              );
            },
          ),
        );
      }
    );
  }

  Widget _buildTemuCard(BuildContext context, StoreProduct product, bool isDark) {
    Color badgeColor = Colors.red;
    if (product.badgeColorHex != null) {
      String hex = product.badgeColorHex!.replaceAll('#', '');
      if (hex.length == 6) hex = "FF$hex";
      badgeColor = Color(int.parse(hex, radix: 16));
    }

    final int discountPct = product.discountPercent;
    final double savedAmount = product.savedAmount;
    final bool showStockWarning = product.stockLevel < 20 && product.stockLevel > 0;
    final bool isOOS = product.isOutOfStock || product.stockLevel <= 0;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => ProductDetailScreen(product: product))
        );
      },
      child: LaundryGlassCard(
        opacity: isDark ? 0.12 : 0.05,
        padding: EdgeInsets.zero,
        borderRadius: 12,
        child: Opacity(
          opacity: isOOS ? 0.6 : 1.0,
              child: ColorFiltered(
                colorFilter: isOOS 
                    ? const ColorFilter.matrix([
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0,      0,      0,      1, 0,
                      ])
                    : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                      Stack(
                        children: [
                          Container(
                            constraints: const BoxConstraints(minHeight: 140), // [FIX] Prevents 0-height collapse while loading
                            width: double.infinity,
                            child: CustomCachedImage(
                              imageUrl: product.imagePath,
                              fit: BoxFit.contain, // [FIX] Restored original so images are not cut off
                              borderRadius: 0,
                            ),
                          ),
                        if (product.badgeText != null)
                          Positioned(
                            bottom: 0, left: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: badgeColor,
                                borderRadius: const BorderRadius.only(topRight: Radius.circular(8)),
                              ),
                              child: Text(
                                product.badgeText!,
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
                              ),
                            ),
                          ),
                        if (isOOS)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black26,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    "OUT OF STOCK",
                                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (product.salesBanner != null && product.salesBanner!.isEnabled)
                          Positioned(
                            top: 5, left: 5,
                            child: SalesBanner(config: product.salesBanner!, mode: SalesBannerMode.badge),
                          ),
                        if (discountPct > 0 && !isOOS)
                          Positioned(
                            top: 0, right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFCC00),
                                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(8)),
                              ),
                              child: Text(
                                "-$discountPct%",
                                style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)
                              ),
                            ),
                          )
                      ],
                    ),

                    // 2. Info Content
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              children: [
                                TextSpan(text: product.name),
                                if (product.brand.isNotEmpty && product.brand != "Generic")
                                  TextSpan(text: "  ${product.brand}", style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.normal)),
                              ]
                            ),
                          ),
                          if (showStockWarning)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                "Only ${product.stockLevel} left",
                                style: const TextStyle(color: Color(0xFFFF5722), fontSize: 11, fontWeight: FontWeight.w600)
                              ),
                            ),
                          if (savedAmount > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFE0B2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.orange.withOpacity(0.3))
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.arrow_downward, size: 10, color: Color(0xFFE65100)),
                                    const SizedBox(width: 2),
                                    Text(
                                      "Save ${CurrencyFormatter.format(savedAmount)}",
                                      style: const TextStyle(color: Color(0xFFE65100), fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
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
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Text(
                                            CurrencyFormatter.format(product.price),
                                            style: const TextStyle(color: Color(0xFFFF5722), fontSize: 15, fontWeight: FontWeight.bold),
                                          ),
                                          if (product.price < product.originalPrice) ...[
                                            const SizedBox(width: 4),
                                            Text(
                                              CurrencyFormatter.format(product.originalPrice),
                                              style: const TextStyle(color: Colors.grey, fontSize: 10, decoration: TextDecoration.lineThrough),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        ...List.generate(5, (i) {
                                          double fill = product.rating - i;
                                          IconData icon;
                                          if (fill >= 1) {
                                            icon = Icons.star;
                                          } else if (fill > 0) {
                                            icon = Icons.star_half;
                                          } else {
                                            icon = Icons.star_border;
                                          }
                                          return Icon(icon, size: 10, color: Colors.amber);
                                        }),
                                        const SizedBox(width: 4),
                                        Text("${product.rating.toStringAsFixed(1)}", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black54)),
                                        const SizedBox(width: 4),
                                        Text("(${product.soldCount})", style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              InkWell(
                                onTap: isOOS ? null : () {
                                  final cart = CartService();
                                  cart.addStoreItem(StoreCartItem(product: product, quantity: 1));
                                  ToastUtils.show(context, "Added to cart!", type: ToastType.success);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: isOOS ? Colors.grey : const Color(0xFFFF5722),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(isOOS ? Icons.remove_shopping_cart : Icons.add_shopping_cart, color: Colors.white, size: 14),
                                ),
                              )
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton(bool isDark) {
    Color color = isDark ? Colors.white10 : Colors.grey.shade200;
    return SafeArea(
      child: Column(
        children: [
           // AppBar Skeleton
           Container(height: 50, margin: const EdgeInsets.all(10), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(25))),
           Container(height: 40, margin: const EdgeInsets.symmetric(vertical: 10), color: color),
           // Grid Skeleton
           Expanded(
             child: GridView.count(
               crossAxisCount: 2, padding: const EdgeInsets.all(10),
               childAspectRatio: 0.62, crossAxisSpacing: 10, mainAxisSpacing: 10,
               children: List.generate(4, (index) => Container(
                 decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
               )),
             ),
           )
        ],
      ),
    );
  }
}
