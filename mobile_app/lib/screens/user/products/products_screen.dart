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

  @override
  void initState() {
    super.initState();
    _fetchContent();
    _storeService.fetchProducts();
    _storeService.fetchCategories();
  }

  Future<void> _fetchContent() async {
    final content = await _contentService.getAppContent();
    if (mounted) setState(() => _appContent = content);
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

    return Scaffold(
      backgroundColor: bgColor, 
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black87),
          onPressed: () {},
        ),
        title: _buildSearchBar(isDark),
        actions: [
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
      body: ListenableBuilder(
        listenable: _storeService,
        builder: (context, _) {
          final products = _filteredProducts;
          return CustomScrollView(
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
                          return Image.network(ads.first.imageUrl, fit: BoxFit.cover);
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
                          return Image.network(ads[1].imageUrl, fit: BoxFit.cover);
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
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Image & Badge
          Expanded(
            flex: 6,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    child: product.imagePath.startsWith('http') 
                        ? Image.network(product.imagePath, fit: BoxFit.cover, errorBuilder: (_,__,___) => Image.asset('assets/images/service_laundry.png', fit: BoxFit.cover))
                        : Image.asset(product.imagePath, fit: BoxFit.cover),
                  ),
                ),
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
                  )
              ],
            ),
          ),
          
          // 2. Content
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    product.name, 
                    maxLines: 2, 
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 13,
                    ),
                  ),
                  
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
                              style: const TextStyle(color: Colors.grey, fontSize: 12, decoration: TextDecoration.lineThrough),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star, size: 12, color: Colors.amber),
                          Text(" ${product.rating}", style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey.shade600)),
                          const SizedBox(width: 6),
                          const Text("🔥", style: TextStyle(fontSize: 12)), 
                          Text(" ${product.soldCount} sold", style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey.shade600)),
                        ],
                      ),
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
}
