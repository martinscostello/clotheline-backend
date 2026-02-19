import 'package:flutter/material.dart';
import 'package:laundry_app/widgets/glass/LiquidBackground.dart';
import 'package:laundry_app/widgets/glass/GlassContainer.dart';
import 'package:laundry_app/theme/app_theme.dart';
import 'admin_cms_content_screen.dart';
import 'admin_cms_promotions_screen.dart';
import '../services/admin_services_screen.dart';
import '../products/admin_products_screen.dart';
import 'admin_categories_screen.dart';
import '../orders/admin_orders_screen.dart';
import '../products/review_moderation_screen.dart';
import '../products/admin_add_product_screen.dart';
import '../products/product_reviews_detail_screen.dart';
import '../promotions/admin_promotions_screen.dart';
import '../services/admin_edit_service_screen.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import '../../../providers/branch_provider.dart';
import '../../../services/laundry_service.dart'; // [NEW]
import '../../../services/store_service.dart'; // [NEW]

class AdminCMSScreen extends StatefulWidget {
  const AdminCMSScreen({super.key});

  @override
  State<AdminCMSScreen> createState() => _AdminCMSScreenState();
}

class _AdminCMSScreenState extends State<AdminCMSScreen> {
  final List<String> _navStack = []; // ['module', 'submodule', ...]
  final Map<String, dynamic> _stackData = {};
  final ValueNotifier<VoidCallback?> _saveTrigger = ValueNotifier(null);

  void _selectModule(String module, {Map<String, dynamic>? data}) {
    setState(() {
      _navStack.clear();
      _stackData.clear();
      _saveTrigger.value = null;
      _navStack.add(module);
      if (data != null) _stackData[module] = data;
    });
  }

  void _pushModule(String module, {Map<String, dynamic>? data}) {
    setState(() {
      _saveTrigger.value = null;
      _navStack.add(module);
      if (data != null) _stackData[module] = data;
    });
  }

  void _popModule() {
    if (_navStack.length > 1) {
      setState(() {
        _saveTrigger.value = null;
        _navStack.removeLast();
      });
    }
  }

  Widget _buildDetailView() {
    if (_navStack.isEmpty) {
      return const Center(child: Text("Select a component to manage", style: TextStyle(color: Colors.white24, fontSize: 16)));
    }

    final current = _navStack.last;
    final data = _stackData[current] ?? {};

    switch (current) {
      case 'home':
        return AdminCMSContentBody(key: const ValueKey('home'), section: 'home', isEmbedded: true, saveTrigger: _saveTrigger);
      case 'ads':
        return AdminCMSContentBody(key: const ValueKey('ads'), section: 'ads', isEmbedded: true, saveTrigger: _saveTrigger);
      case 'branding':
        return AdminCMSContentBody(key: const ValueKey('branding'), section: 'branding', isEmbedded: true, saveTrigger: _saveTrigger);
      case 'promotions':
        return AdminCMSPromotionsBody(key: const ValueKey('promotions'), isEmbedded: true, saveTrigger: _saveTrigger, onNavigate: (path) => _pushModule(path));
      case 'promocodes':
        return AdminPromotionsBody(key: const ValueKey('promocodes'), isEmbedded: true); 
      case 'services':
        return AdminServicesBody(key: const ValueKey('services'), isEmbedded: true, onNavigate: (path, d) => _pushModule(path, data: d));
      case 'edit_service':
        return AdminEditServiceBody(key: ValueKey('edit_service_${data['service']?.id ?? 'new'}'), isEmbedded: true, service: data['service'], scopeBranch: data['scopeBranch'], saveTrigger: _saveTrigger);
      case 'product_categories':
        return const AdminCategoriesBody(key: ValueKey('product_categories'), isEmbedded: true);
      case 'products':
        return AdminProductsBody(key: const ValueKey('products'), isEmbedded: true, onNavigate: (path, d) => _pushModule(path, data: d));
      case 'add_product':
        return AdminAddProductBody(key: ValueKey('add_product_${data['product']?.id ?? 'new'}'), isEmbedded: true, product: data['product'], branchId: data['branchId'], saveTrigger: _saveTrigger);
      case 'reviews':
        return ReviewModerationBody(key: const ValueKey('reviews'), isEmbedded: true, onNavigate: (path, d) => _pushModule(path, data: d));
      case 'review_detail':
        return ProductReviewsDetailBody(key: ValueKey('review_detail_${data['productId']}'), isEmbedded: true, productId: data['productId'], productName: data['productName'], reviews: data['reviews']);
      default:
        return Center(child: Text("Component '$current' not implemented"));
    }
  }
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
          final user = authService.currentUser;
          final permissions = user != null ? (user['permissions'] ?? {}) : {};
          final isMaster = user != null && user['isMasterAdmin'] == true;

          final canManageCMS = isMaster || permissions['manageCMS'] == true;
          final canManageOrders = isMaster || permissions['manageOrders'] == true;
          final canManageServices = isMaster || permissions['manageServices'] == true;
          final canManageProducts = isMaster || permissions['manageProducts'] == true;

          final isTablet = MediaQuery.of(context).size.width >= 600;

          return Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              title: const Text("Content Management", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: Colors.transparent,
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3), // Faded soft
                  border: const Border(bottom: BorderSide(color: Colors.white10)),
                ),
              ),
              elevation: 0,
              leading: (isTablet && _navStack.length > 1)
                  ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _popModule)
                  : null,
              actions: [
                // [Tablet] Branch Selector for specific modules
                if (isTablet && ['services', 'product_categories', 'products'].contains(_navStack.isNotEmpty ? _navStack.last : ''))
                  Consumer<BranchProvider>(
                    builder: (context, branchProvider, _) {
                      if (branchProvider.branches.isEmpty) return const SizedBox.shrink();
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(20)
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            dropdownColor: const Color(0xFF202020),
                            value: branchProvider.selectedBranch?.id,
                            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                            onChanged: (val) {
                                if (val != null) {
                                   final branch = branchProvider.branches.firstWhere((b) => b.id == val);
                                   branchProvider.selectBranch(branch);
                                   
                                   final currentModule = _navStack.isNotEmpty ? _navStack.last : '';
                                   if (currentModule == 'services') {
                                       Provider.of<LaundryService>(context, listen: false).fetchServices(branchId: val, includeHidden: true);
                                   } else if (currentModule == 'product_categories') {
                                       Provider.of<StoreService>(context, listen: false).fetchCategories(branchId: val);
                                   } else if (currentModule == 'products') {
                                       Provider.of<StoreService>(context, listen: false).fetchProducts(branchId: val, forceRefresh: true);
                                   }
                                }
                            },
                            items: branchProvider.branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name, style: const TextStyle(color: Colors.white, fontSize: 13)))).toList(),
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(width: 10),

                ValueListenableBuilder<VoidCallback?>(
                  valueListenable: _saveTrigger,
                  builder: (context, onSave, _) {
                    if (onSave == null) return const SizedBox.shrink();
                    return IconButton(
                      icon: const Icon(Icons.save, color: AppTheme.secondaryColor),
                      onPressed: onSave,
                    );
                  },
                ),
                const SizedBox(width: 10),
              ],
            ),
            body: LiquidBackground(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bool isTablet = constraints.maxWidth >= 600;
                  
                  Widget listContent = MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        top: MediaQuery.paddingOf(context).top + kToolbarHeight + 2, 
                        bottom: 150, left: 20, right: 20
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("App Appearance", style: TextStyle(color: Colors.white54, fontSize: 14)),
                          const SizedBox(height: 10),
                          _buildCMSCard(
                            title: "Home Screen",
                            subtitle: "Hero carousel & Featured services.",
                            icon: Icons.home_filled,
                            isSelected: isTablet && _navStack.contains('home'),
                            onTap: () {
                              if (isTablet) {
                                _selectModule('home');
                              } else {
                                _checkAndNavigate(context, 'manageCMS', "Home Screen", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCMSContentScreen(section: 'home'))));
                              }
                            },
                          ),
                          const SizedBox(height: 15),
                          _buildCMSCard(
                            title: "Ads & Banners",
                            subtitle: "Manage promotional banners across the app.",
                            icon: Icons.campaign,
                            isSelected: isTablet && _navStack.contains('ads'),
                            onTap: () {
                              if (isTablet) {
                                _selectModule('ads');
                              } else {
                                _checkAndNavigate(context, 'manageCMS', "Ads & Banners", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCMSContentScreen(section: 'ads'))));
                              }
                            },
                          ),
                          const SizedBox(height: 15),
                          _buildCMSCard(
                            title: "Branding & Delivery Assurance",
                            subtitle: "Update brands, slogans and delivery banners.",
                            icon: Icons.text_fields,
                            isSelected: isTablet && _navStack.contains('branding'),
                            onTap: () {
                              if (isTablet) {
                                _selectModule('branding');
                              } else {
                                _checkAndNavigate(context, 'manageCMS', "Branding", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCMSContentScreen(section: 'branding'))));
                              }
                            },
                          ),
                          const SizedBox(height: 15),
                          _buildCMSCard(
                            title: "Promotions",
                            subtitle: "Free shipping thresholds & global offers.",
                            icon: Icons.local_offer,
                            color: Colors.greenAccent,
                            isSelected: isTablet && _navStack.contains('promotions'),
                            onTap: () {
                              if (isTablet) {
                                _selectModule('promotions');
                              } else {
                                _checkAndNavigate(context, 'manageCMS', "Promotions", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCMSPromotionsScreen())));
                              }
                            },
                          ),
                          const SizedBox(height: 30),

                          const Text("Store Data", style: TextStyle(color: Colors.white54, fontSize: 14)),
                          const SizedBox(height: 10),

                          _buildCMSCard(
                            title: "Manage Service Categories", 
                            subtitle: "Update service categories & prices.",
                            icon: Icons.category, 
                            color: Colors.blueAccent,
                            isSelected: isTablet && _navStack.contains('services'),
                            onTap: () {
                              if (isTablet) {
                                _selectModule('services');
                              } else {
                                _checkAndNavigate(context, 'manageServices', "Services", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminServicesScreen())));
                              }
                            },
                          ),

                          const SizedBox(height: 15),
                          _buildCMSCard(
                            title: "Manage Product Categories", 
                            subtitle: "Create & edit store categories (e.g. Fragrance).",
                            icon: Icons.category_outlined, 
                            color: Colors.orangeAccent,
                            isSelected: isTablet && _navStack.contains('product_categories'),
                            onTap: () {
                              if (isTablet) {
                                _selectModule('product_categories');
                              } else {
                                _checkAndNavigate(context, 'manageProducts', "Product Categories", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCategoriesScreen())));
                              }
                            },
                          ),
                          const SizedBox(height: 15),
                          _buildCMSCard(
                            title: "Manage Products", 
                            subtitle: "Update store inventory and descriptions.",
                            icon: Icons.shopping_bag, 
                            color: Colors.purpleAccent,
                            isSelected: isTablet && _navStack.contains('products'),
                            onTap: () {
                              if (isTablet) {
                                _selectModule('products');
                              } else {
                                _checkAndNavigate(context, 'manageProducts', "Products", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminProductsScreen())));
                              }
                            },
                          ),
                          const SizedBox(height: 15),
                          _buildCMSCard(
                            title: "Review Moderation", 
                            subtitle: "View and hide product reviews.",
                            icon: Icons.rate_review_outlined, 
                            color: Colors.yellowAccent,
                            isSelected: isTablet && _navStack.contains('reviews'),
                            onTap: () {
                              if (isTablet) {
                                _selectModule('reviews');
                              } else {
                                _checkAndNavigate(context, 'manageProducts', "Reviews", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReviewModerationScreen())));
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );

                  if (isTablet) {
                    return Row(
                      children: [
                        Expanded(flex: 4, child: listContent),
                        const VerticalDivider(color: Colors.white10, width: 1),
                        Expanded(
                          flex: 6,
                          child: Padding(
                            padding: const EdgeInsets.only(top: kToolbarHeight + 20),
                            child: _buildDetailView(),
                          ),
                        ),
                      ],
                    );
                  }

                  return listContent;
                },
              ),
            ),
          );
      },
    );
  }

  void _checkAndNavigate(BuildContext context, String permissionKey, String featureName, VoidCallback onGranted) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;
    if (user['isMasterAdmin'] == true) {
      onGranted();
      return;
    }

    final permissions = user['permissions'] ?? {};
    if (permissions[permissionKey] == true) {
      onGranted();
    } else {
      _showDeniedDialog(context);
      auth.logPermissionViolation(featureName);
    }
  }

  void _showDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.redAccent, width: 2)
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 10),
            Text("Access Denied", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          "You do not have permission to access this page, an auto request has been sent to the master admin of your attempt to access this page",
          style: TextStyle(color: Colors.white70)
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK", style: TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold))
          )
        ],
      )
    );
  }

  Widget _buildCMSCard({
    required String title, 
    required String subtitle, 
    required IconData icon, 
    required VoidCallback onTap,
    Color? color,
    bool isSelected = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        opacity: isSelected ? 0.2 : 0.1,
        padding: const EdgeInsets.all(15),
        border: isSelected 
          ? Border.all(color: AppTheme.secondaryColor.withOpacity(0.5), width: 1.5)
          : null,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (color ?? AppTheme.secondaryColor).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color ?? AppTheme.secondaryColor, size: 28),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 4),
                   Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
          ],
        ),
      ),
    );
  }
}
