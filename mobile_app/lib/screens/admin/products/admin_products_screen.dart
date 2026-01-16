import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass/GlassContainer.dart';
import '../../../widgets/glass/LiquidBackground.dart';
import '../../../services/store_service.dart';
import '../../../models/store_product.dart';
import '../../../utils/currency_formatter.dart';
import '../../../widgets/custom_cached_image.dart'; // Added Import
import 'admin_add_product_screen.dart';

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch products on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<StoreService>(context, listen: false).fetchProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Manage Products", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        leading: const BackButton(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => Provider.of<StoreService>(context, listen: false).fetchProducts(),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminAddProductScreen()),
          );
          if (context.mounted) {
            Provider.of<StoreService>(context, listen: false).fetchProducts(forceRefresh: true);
          }
        },
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add Product", style: TextStyle(color: Colors.white)),
      ),
      body: LiquidBackground(
        child: Consumer<StoreService>(
          builder: (context, storeService, child) {
            if (storeService.isLoading && storeService.products.isEmpty) {
              return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
            }

            if (storeService.products.isEmpty) {
              return const Center(child: Text("No products found", style: TextStyle(color: Colors.white54)));
            }

            return RefreshIndicator(
              onRefresh: () => storeService.fetchProducts(),
              color: AppTheme.primaryColor,
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 100, 20, 80),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 0.75, // Taller for price/stock info
                ),
                itemCount: storeService.products.length,
                itemBuilder: (context, index) {
                  final product = storeService.products[index];
                  return _buildProductCard(product);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProductCard(StoreProduct product) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AdminAddProductScreen(product: product)), // Edit Mode
        );
        if (context.mounted) {
            Provider.of<StoreService>(context, listen: false).fetchProducts(forceRefresh: true);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF202020),
        ),
        child: Stack(
          children: [
            // Background Image
            if (product.imageUrls.isNotEmpty)
              Positioned.fill(
                child: CustomCachedImage(
                  imageUrl: product.imageUrls.first,
                  fit: BoxFit.cover,
                  borderRadius: 20,
                ),
              ),
            // Gradient for text visibility at bottom
            Positioned(
              bottom: 0, left: 0, right: 0,
              height: 100,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)]
                  )
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Badges
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (product.discountPercentage > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                          child: Text("-${product.discountPercentage}%", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        )
                      else
                        const SizedBox(),
                      
                      if (product.stockLevel <= 5)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)),
                          child: Text(product.stockLevel == 0 ? "OUT" : "LOW", style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  
                  // Bottom Info
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name, 
                        maxLines: 2, 
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)
                      ),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            CurrencyFormatter.format(product.price), 
                            style: const TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold, fontSize: 14)
                          ),
                          Text(
                            "Qty: ${product.stockLevel}", 
                            style: const TextStyle(color: Colors.white70, fontSize: 12)
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
