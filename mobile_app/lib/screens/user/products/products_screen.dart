import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:laundry_app/theme/app_theme.dart';
import '../../../utils/currency_formatter.dart';
import '../../../services/store_service.dart';
import '../../../services/cart_service.dart';
import '../../../models/store_product.dart';
import 'product_detail_screen.dart';
import 'store_cart_screen.dart';
import 'package:laundry_app/services/content_service.dart';
import 'package:laundry_app/models/app_content_model.dart';
import '../../../widgets/custom_cached_image.dart'; 
import '../favorites_screen.dart'; // Fixed Import

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
    // 1. Load Content Cache
    await _contentService.loadFromCache().then((c) {
       if (mounted) setState(() => _appContent = c);
    });

    // 2. Load Product Cache
    await _storeService.loadFromCache();

    if (mounted) {
      setState(() => _isHydrated = true);
    }

    // 3. Silent Sync
    _performSilentSync();
  }
  
  Future<void> _performSilentSync() async {
     _contentService.fetchFromApi().then((c) {
        if (mounted && c != null) setState(() => _appContent = c);
     });
     _storeService.fetchFromApi();
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
      backgroundColor: bgColor, 
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        titleSpacing: 10,
        automaticallyImplyLeading: false, // Prevents back button on main tab
        title: _buildSearchBar(isDark),
        actions: [
          IconButton(
            icon: Icon(Icons.favorite_border, color: isDark ? Colors.white : Colors.black87),
            onPressed: () {
               Navigator.of(context).push(MaterialPageRoute(builder: (context) => const FavoritesScreen()));
            },
          ),
          ListenableBuilder(
            listenable: cartService,
            builder: (context, _) {
              return Stack(
                children: [
                  IconButton(
                    icon: Icon(Icons.shopping_cart_outlined, color: isDark ? Colors.white : Colors.black87),
                    onPressed: () {
                       Navigator.of(context).push(MaterialPageRoute(builder: (context) => const StoreCartScreen()));
                    },
                  ),
                  if (cartService.storeItems.isNotEmpty)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF5722),
                          shape: BoxShape.circle,
                        ),
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
          const SizedBox(width: 10),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: _buildCategories(isDark),
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _performSilentSync,
        color: const Color(0xFFFF5722),
        child: ListenableBuilder(
          listenable: _storeService,
          builder: (context, _) {
            final products = _filteredProducts;
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(), // Allow refresh even if empty
              slivers: [
                // 1. Sales Banner (Bigger)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 0),
                  child: AspectRatio(
                    aspectRatio: 16/9,
                    child: Builder(
                      builder: (context) {
                        final ads = _appContent?.productAds.where((a) => a.active).toList() ?? [];
                        if (ads.isNotEmpty) {
                          return CustomCachedImage(
                            imageUrl: ads.first.imageUrl,
                            fit: BoxFit.cover,
                            borderRadius: 0,
                          );
                        }
                        return Image.asset('assets/images/banner_sales.png', fit: BoxFit.cover);
                      }
                    ),
                  ),
                ),
              ),

              // 2. Trust/Guarantee Banner (Smaller, below sales)
              SliverToBoxAdapter(
                child: Container(
                  height: 60,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Builder(
                      builder: (context) {
                        final ads = _appContent?.productAds.where((a) => a.active).toList() ?? [];
                        if (ads.length > 1) {
                          return CustomCachedImage(
                            imageUrl: ads[1].imageUrl,
                            fit: BoxFit.cover,
                            borderRadius: 0,
                          );
                        }
                        return Image.asset('assets/images/banner_trust.png', fit: BoxFit.cover);
                      }
                  ),
                ),
              ),

              // 3. Product Grid
              if (products.isEmpty)
                 SliverFillRemaining(
                   child: Center(child: Text("No products found", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey))),
                 )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.62,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final product = products[index];
                        return _buildTemuCard(context, product, isDark).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1);
                      },
                      childCount: products.length,
                    ),
                  ),
                ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 100)), // Bottom padding
            ],
          );
        }
      ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14),
        onChanged: (val) {
          setState(() => _searchQuery = val);
        },
        decoration: InputDecoration(
          hintText: "Search products",
          hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
          prefixIcon: Icon(Icons.search, size: 20, color: isDark ? Colors.white54 : Colors.black45),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 15),
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
    );
  }

  Widget _buildCategories(bool isDark) {
    return Container(
      height: 50,
      color: isDark ? Colors.black : Colors.white,
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

  Widget _buildTemuCard(BuildContext context, StoreProduct product, bool isDark) {
    Color badgeColor = Colors.red;
    if (product.badgeColorHex != null) {
      String hex = product.badgeColorHex!.replaceAll('#', '');
      if (hex.length == 6) hex = "FF$hex";
      badgeColor = Color(int.parse(hex, radix: 16));
    }

    // Calculations
    final int discountPct = product.discountPercent;
    final double savedAmount = product.savedAmount;
    final bool showStockWarning = product.stockLevel < 20;

    return GestureDetector(
      onTap: () {
         Navigator.of(context).push(
           MaterialPageRoute(builder: (context) => ProductDetailScreen(product: product))
         );
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Image & Badges
          Expanded(
            flex: 6,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    child: CustomCachedImage(
                      imageUrl: product.imagePath,
                      fit: BoxFit.cover,
                      borderRadius: 0, 
                    ),
                  ),
                ),
                // Original Bottom-Left Badge (e.g. "Almost Sold Out")
                if (product.badgeText != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
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
                // New Top-Right Discount Badge
                if (discountPct > 0)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFCC00), // Yellow/Orange
                        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(8), topRight: Radius.circular(8)),
                      ),
                      child: Text(
                        "-$discountPct%", 
                        style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)
                      ),
                    ),
                  )
              ],
            ),
          ),
          
          // 2. Content
          Expanded(
            flex: 6, // Increased flex for content
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Text Block
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name & Brand
                      RichText(
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 13,
                          ),
                          children: [
                            TextSpan(text: product.name),
                            if (product.brand.isNotEmpty && product.brand != "Generic")
                              TextSpan(text: "  ${product.brand}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ]
                        ),
                      ),
                      const SizedBox(height: 4),
                      
                      // Stock Warning
                      if (showStockWarning)
                        Text(
                          "Only ${product.stockLevel} left", 
                          style: const TextStyle(color: Color(0xFFFF5722), fontSize: 11, fontWeight: FontWeight.w500)
                        ),
                        
                      const SizedBox(height: 4),
                      
                      // Savings Box
                      if (savedAmount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE0B2), // Light Orange
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.orange.withOpacity(0.3))
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.arrow_downward, size: 10, color: Color(0xFFE65100)), // Dark Orange
                              Text(
                                "Saved ${CurrencyFormatter.format(savedAmount)} extra",
                                style: const TextStyle(color: Color(0xFFE65100), fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  // Bottom Price Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Price & Rating
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                CurrencyFormatter.format(product.price), 
                                style: const TextStyle(color: Color(0xFFFF5722), fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 4),
                              if (product.price < product.originalPrice)
                                 Text(
                                  CurrencyFormatter.format(product.originalPrice), 
                                  style: const TextStyle(color: Colors.grey, fontSize: 11, decoration: TextDecoration.lineThrough),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.star, size: 10, color: Colors.amber),
                              Text(" ${product.rating}", style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.grey.shade600)),
                              const SizedBox(width: 4),
                              Text("(${product.soldCount} sold)", style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey.shade400)),
                            ],
                          ),
                        ],
                      ),
                      
                      // Quick Cart Button
                      InkWell(
                        onTap: () {
                          // Quick Add to Cart
                          final cart = CartService();
                          cart.addStoreItem(StoreCartItem(product: product, quantity: 1));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Added to cart!"), 
                              duration: Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            )
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF5722),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add_shopping_cart, color: Colors.white, size: 16),
                        ),
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
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
