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
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';

class AdminCMSScreen extends StatelessWidget {
  const AdminCMSScreen({super.key});

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

          return Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              title: const Text("Content Management", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
            body: LiquidBackground(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 100, bottom: 100, left: 20, right: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (canManageCMS) ...[
                      const Text("App Appearance", style: TextStyle(color: Colors.white54, fontSize: 14)),
                      const SizedBox(height: 10),
                      _buildCMSCard(
                        title: "Home Screen",
                        subtitle: "Hero carousel & Featured services.",
                        icon: Icons.home_filled,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCMSContentScreen(section: 'home'))),
                      ),
                      const SizedBox(height: 15),
                      _buildCMSCard(
                        title: "Ads & Banners",
                        subtitle: "Manage promotional banners across the app.",
                        icon: Icons.campaign,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCMSContentScreen(section: 'ads'))),
                      ),
                      const SizedBox(height: 15),
                      const SizedBox(height: 15),
                      // _buildCMSCard(
                      //   title: "Branding Text",
                      //   subtitle: "Update brands and slogans.",
                      //   icon: Icons.text_fields,
                      //   onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCMSContentScreen(section: 'branding'))),
                      // ),
                      const SizedBox(height: 15),
                      _buildCMSCard(
                        title: "Promotions",
                        subtitle: "Free shipping thresholds & global offers.",
                        icon: Icons.local_offer,
                        color: Colors.greenAccent,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCMSPromotionsScreen())),
                      ),
                      const SizedBox(height: 30),
                    ],

                    if (canManageOrders || canManageServices || canManageProducts)
                      const Text("Store Data", style: TextStyle(color: Colors.white54, fontSize: 14)),
                    const SizedBox(height: 10),

                    if (canManageOrders) ...[
                      const SizedBox(height: 15),
                      _buildCMSCard(
                        title: "Manage Orders",
                        subtitle: "View & Update Order Status.",
                        icon: Icons.assignment_outlined,
                        color: Colors.pinkAccent,
                        onTap: () {
                           Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminOrdersScreen()));
                        },
                      ),
                    ],
                    
                    if (canManageServices) ...[
                      const SizedBox(height: 15),
                      _buildCMSCard(
                        title: "Manage Service Categories", 
                        subtitle: "Update service categories & prices.",
                        icon: Icons.category, 
                        color: Colors.blueAccent,
                        onTap: () {
                           Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminServicesScreen()));
                        },
                      ),
                    ],

                    if (canManageProducts) ...[
                      const SizedBox(height: 15),
                      _buildCMSCard(
                        title: "Manage Product Categories", 
                        subtitle: "Create & edit store categories (e.g. Fragrance).",
                        icon: Icons.category_outlined, 
                        color: Colors.orangeAccent,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCategoriesScreen())),
                      ),
                      const SizedBox(height: 15),
                      _buildCMSCard(
                        title: "Manage Products", 
                        subtitle: "Update store inventory and descriptions.",
                        icon: Icons.shopping_bag, 
                        color: Colors.purpleAccent,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminProductsScreen())),
                      ),
                    ],

                    if (canManageServices) ...[
                      const SizedBox(height: 15),
                      // _buildCMSCard(
                      //   title: "Delivery Fees",
                      //   subtitle: "Set delivery charges.",
                      //   icon: Icons.local_shipping,
                      //   onTap: () {},
                      // ),
                    ],
                  ],
                ),
              ),
            ),
          );
      }
    );
  }

  Widget _buildCMSCard({
    required String title, 
    required String subtitle, 
    required IconData icon, 
    required VoidCallback onTap,
    Color? color
  }) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        opacity: 0.1,
        padding: const EdgeInsets.all(20),
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
