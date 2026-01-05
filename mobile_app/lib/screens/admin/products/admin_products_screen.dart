import 'package:flutter/material.dart';
import 'package:laundry_app/models/store_product.dart';
import 'package:laundry_app/services/store_service.dart';
import 'package:laundry_app/theme/app_theme.dart';
import 'package:laundry_app/widgets/glass/GlassContainer.dart';
import 'package:laundry_app/widgets/glass/LiquidBackground.dart';
import 'admin_add_product_screen.dart';
import 'admin_product_categories_screen.dart';

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  final StoreService _storeService = StoreService();
  // Using local listener wrapper or FutureBuilder? 
  // StoreService uses notifyListeners, so we should listen.

  @override
  void initState() {
    super.initState();
    _storeService.addListener(_onServiceUpdate);
    _storeService.fetchProducts();
  }
  
  @override
  void dispose() {
    _storeService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if(mounted) setState((){});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Manage Products", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: LiquidBackground(
        child: Column(
          children: [
            const SizedBox(height: 100),
            // Top Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                         Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminProductCategoriesScreen()));
                      },
                      child: GlassContainer(
                        opacity: 0.1,
                        child: Container(
                          height: 100,
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.category, color: Colors.white, size: 30),
                              SizedBox(height: 5),
                              Text("Categories", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAddProductScreen()));
                      },
                      child: GlassContainer(
                        opacity: 0.1,
                        child: Container(
                          height: 100,
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.add_box, color: AppTheme.secondaryColor, size: 30),
                              SizedBox(height: 5),
                              Text("Add Product", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Product List
            Expanded(
              child: _storeService.isLoading 
                  ? const Center(child: CircularProgressIndicator()) 
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _storeService.products.length,
                      itemBuilder: (ctx, i) {
                        final p = _storeService.products[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 15),
                          child: GlassContainer(
                            opacity: 0.1,
                            child: ListTile(
                              leading: Container(
                                width: 50, height: 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  image: p.imageUrls.isNotEmpty 
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: p.imageUrls.isNotEmpty 
                                      ? Image.network(
                                          p.imageUrls.first,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return const Center(child: Icon(Icons.broken_image, color: Colors.redAccent, size: 20));
                                          },
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) return child;
                                            return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white30)));
                                          },
                                        )
                                      : const Center(child: Icon(Icons.image, color: Colors.white24)),
                                ),
                              ),
                              title: Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              subtitle: Text("₦${p.price.toStringAsFixed(0)} • Stock: ${p.stockLevel} • ${p.category}", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              trailing: IconButton(
                                icon: const Icon(Icons.edit, color: Colors.white),
                                onPressed: () {
                                   Navigator.push(context, MaterialPageRoute(builder: (_) => AdminAddProductScreen(productToEdit: p)));
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
