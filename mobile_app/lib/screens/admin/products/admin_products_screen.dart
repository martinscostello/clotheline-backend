import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass/LiquidBackground.dart';
import '../../../services/store_service.dart';
import '../../../models/store_product.dart';
import '../../../utils/currency_formatter.dart';
import '../../../widgets/custom_cached_image.dart';
// Just in case
import '../../../providers/branch_provider.dart'; // [FIXED] Added Import
import 'admin_add_product_screen.dart';

class AdminProductsScreen extends StatelessWidget {
  const AdminProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text("Manage Products", style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.transparent,
          leading: const BackButton(color: Colors.white),
        ),
        body: const LiquidBackground(
          child: AdminProductsBody(),
        ),
      ),
    );
  }
}

class AdminProductsBody extends StatefulWidget {
  final bool isEmbedded;
  final Function(String, Map<String, dynamic>)? onNavigate;
  const AdminProductsBody({super.key, this.isEmbedded = false, this.onNavigate});

  @override
  State<AdminProductsBody> createState() => _AdminProductsBodyState();
}

class _AdminProductsBodyState extends State<AdminProductsBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final branchProvider = Provider.of<BranchProvider>(context, listen: false);
    final storeService = Provider.of<StoreService>(context, listen: false);
    
    // Auto Select first branch if none
    if (branchProvider.selectedBranch == null && branchProvider.branches.isNotEmpty) {
      branchProvider.selectBranch(branchProvider.branches.first);
    }

    if (branchProvider.selectedBranch != null) {
      await storeService.fetchProducts(branchId: branchProvider.selectedBranch!.id);
    }
  }

  Future<void> _onBranchChanged(String? newId) async {
    if (newId == null) return;
    final branchProvider = Provider.of<BranchProvider>(context, listen: false);
    final storeService = Provider.of<StoreService>(context, listen: false);
    
    final branch = branchProvider.branches.firstWhere((b) => b.id == newId);
    branchProvider.selectBranch(branch); // Update Context
    
    storeService.fetchProducts(branchId: newId); // Fetch for new Branch
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Consumer2<StoreService, BranchProvider>(
          builder: (context, storeService, branchProvider, child) {
            
            if (branchProvider.selectedBranch == null) {
               return const Center(child: Text("Please select a branch to manage products", style: TextStyle(color: Colors.white54, fontSize: 16)));
            }

            if (storeService.isLoading && storeService.products.isEmpty) {
              return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
            }

            if (storeService.products.isEmpty) {
              return Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 60, color: Colors.white24),
                  const SizedBox(height: 10),
                  Text("No products in ${branchProvider.selectedBranch!.name}", style: const TextStyle(color: Colors.white54)),
                  const SizedBox(height: 5),
                  const Text("Click 'Add' to start stocking inventory", style: TextStyle(color: Colors.white30, fontSize: 12)),
                ],
              ));
            }

            return RefreshIndicator(
              onRefresh: () => storeService.fetchProducts(branchId: branchProvider.selectedBranch!.id),
              color: AppTheme.primaryColor,
              child: GridView.builder(
                padding: EdgeInsets.fromLTRB(20, widget.isEmbedded ? 20 : 100, 20, 100),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 0.70, // Optimized
                ),
                itemCount: storeService.products.length,
                itemBuilder: (context, index) {
                  final product = storeService.products[index];
                  return _buildProductCard(product, branchProvider.selectedBranch!.id);
                },
              ),
            );
          },
        ),
        
        // FAB equivalent for embedded
        Consumer<BranchProvider>(
          builder: (context, branchProvider, _) {
            if (branchProvider.selectedBranch == null) return const SizedBox();
            return Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton.extended(
                onPressed: () async {
                  if (widget.isEmbedded && widget.onNavigate != null) {
                    widget.onNavigate!('add_product', {
                      'branchId': branchProvider.selectedBranch!.id,
                      'product': null,
                    });
                  } else {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AdminAddProductScreen(
                        branchId: branchProvider.selectedBranch!.id,
                        product: null
                      )),
                    );
                    if (context.mounted && branchProvider.selectedBranch != null) {
                      Provider.of<StoreService>(context, listen: false).fetchProducts(branchId: branchProvider.selectedBranch!.id, forceRefresh: true);
                    }
                  }
                },
                backgroundColor: AppTheme.primaryColor,
                icon: const Icon(Icons.add, color: Colors.white),
                label: Text("Add to ${branchProvider.selectedBranch!.name}", style: const TextStyle(color: Colors.white)),
              ),
            );
          },
        ),

        if (!widget.isEmbedded)
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            right: 20,
            child: Consumer<BranchProvider>(
              builder: (context, branchProvider, _) {
                if (branchProvider.branches.isEmpty) return const SizedBox();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20)
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      dropdownColor: const Color(0xFF202020),
                      value: branchProvider.selectedBranch?.id,
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                      onChanged: _onBranchChanged,
                      items: branchProvider.branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name, style: const TextStyle(color: Colors.white)))).toList(),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildProductCard(StoreProduct product, String branchId) {
    return GestureDetector(
      onTap: () async {
        if (widget.isEmbedded && widget.onNavigate != null) {
          widget.onNavigate!('add_product', {
            'product': product,
            'branchId': branchId,
          });
        } else {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AdminAddProductScreen(
              product: product,
              branchId: branchId
            )), 
          );
          if (context.mounted) {
              Provider.of<StoreService>(context, listen: false).fetchProducts(branchId: branchId, forceRefresh: true);
          }
        }
      },
      child: Container(
        clipBehavior: Clip.antiAlias,
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
                  borderRadius: 0, // container clips
                ),
              ),
            // Gradient
            Positioned(
              bottom: 0, left: 0, right: 0,
              height: 120,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.zero, // Parent clips
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.9)]
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
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)
                      ),
                      const SizedBox(height: 4),
                       Text(
                        CurrencyFormatter.format(product.price), 
                        style: const TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold, fontSize: 14)
                      ),
                      Text(
                        "Qty: ${product.stockLevel}", 
                        style: const TextStyle(color: Colors.white70, fontSize: 11)
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
