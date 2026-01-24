import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:laundry_app/services/store_service.dart';
import 'package:laundry_app/services/favorites_service.dart';
import 'package:laundry_app/widgets/custom_cached_image.dart';
import 'package:laundry_app/utils/currency_formatter.dart';
import 'products/product_detail_screen.dart'; // Fix import path
import 'package:laundry_app/widgets/glass/LaundryGlassBackground.dart';
import 'package:laundry_app/widgets/glass/UnifiedGlassHeader.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final storeService = Provider.of<StoreService>(context);
    final favoritesService = Provider.of<FavoritesService>(context);

    // Filter products that are in favorites
    final favoriteProducts = storeService.products
        .where((p) => favoritesService.isFavorite(p.id))
        .toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: LaundryGlassBackground(
        child: Stack(
          children: [
            // 1. Content
            favoriteProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                         Icon(Icons.favorite_border, size: 80, color: isDark ? Colors.white24 : Colors.grey.shade300),
                         const SizedBox(height: 16),
                         Text("No favorites yet", style: TextStyle(fontSize: 18, color: isDark ? Colors.white54 : Colors.grey)),
                         const SizedBox(height: 8),
                         Text("Heart items to see them here", style: TextStyle(fontSize: 14, color: isDark ? Colors.white30 : Colors.grey.shade400)),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 130, left: 16, right: 16, bottom: 40),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                       crossAxisCount: 2,
                       childAspectRatio: 0.70,
                       crossAxisSpacing: 16,
                       mainAxisSpacing: 16,
                    ),
                    itemCount: favoriteProducts.length,
                    itemBuilder: (context, index) {
                    final product = favoriteProducts[index];
                    return GestureDetector(
                      onTap: () {
                         Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)));
                      },
                      child: Container(
                        decoration: BoxDecoration(
                           color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                           borderRadius: BorderRadius.circular(16),
                           boxShadow: [
                             if (!isDark)
                                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                           ]
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Image
                            Expanded(
                              flex: 4,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                   CustomCachedImage(imageUrl: product.imagePath, fit: BoxFit.cover, borderRadius: 0),
                                   Positioned(
                                     top: 8, right: 8,
                                     child: GestureDetector(
                                       onTap: () {
                                         favoritesService.toggleFavorite(product.id);
                                       },
                                       child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                          child: const Icon(Icons.favorite, color: Colors.red, size: 18)
                                       ),
                                     ),
                                   )
                                ],
                              ),
                            ),
                            // Details
                            Expanded(
                              flex: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                                    Text(CurrencyFormatter.format(product.price), style: const TextStyle(color: Color(0xFFFF5722), fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),

            // 2. Header
            Positioned(
              top: 0, left: 0, right: 0,
              child: UnifiedGlassHeader(
                isDark: isDark,
                title: Text("My Favorites", style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
                onBack: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
