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
                padding: EdgeInsets.only(
                  top: MediaQuery.paddingOf(context).top + kToolbarHeight + 20, 
                  bottom: 100, left: 20, right: 20
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
                      onTap: () => _checkAndNavigate(context, 'manageCMS', "Home Screen", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCMSContentScreen(section: 'home')))),
                    ),
                    const SizedBox(height: 15),
                    _buildCMSCard(
                      title: "Ads & Banners",
                      subtitle: "Manage promotional banners across the app.",
                      icon: Icons.campaign,
                      onTap: () => _checkAndNavigate(context, 'manageCMS', "Ads & Banners", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCMSContentScreen(section: 'ads')))),
                    ),
                    const SizedBox(height: 15),
                    _buildCMSCard(
                      title: "Branding & Delivery Assurance",
                      subtitle: "Update brands, slogans and delivery banners.",
                      icon: Icons.text_fields,
                      onTap: () => _checkAndNavigate(context, 'manageCMS', "Branding", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCMSContentScreen(section: 'branding')))),
                    ),
                    const SizedBox(height: 15),
                    _buildCMSCard(
                      title: "Promotions",
                      subtitle: "Free shipping thresholds & global offers.",
                      icon: Icons.local_offer,
                      color: Colors.greenAccent,
                      onTap: () => _checkAndNavigate(context, 'manageCMS', "Promotions", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCMSPromotionsScreen()))),
                    ),
                    const SizedBox(height: 30),

                    const Text("Store Data", style: TextStyle(color: Colors.white54, fontSize: 14)),
                    const SizedBox(height: 10),

                    _buildCMSCard(
                      title: "Manage Orders",
                      subtitle: "View & Update Order Status.",
                      icon: Icons.assignment_outlined,
                      color: Colors.pinkAccent,
                      onTap: () => _checkAndNavigate(context, 'manageOrders', "Orders", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminOrdersScreen()))),
                    ),
                    
                    const SizedBox(height: 15),
                    _buildCMSCard(
                      title: "Manage Service Categories", 
                      subtitle: "Update service categories & prices.",
                      icon: Icons.category, 
                      color: Colors.blueAccent,
                      onTap: () => _checkAndNavigate(context, 'manageServices', "Services", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminServicesScreen()))),
                    ),

                    const SizedBox(height: 15),
                    _buildCMSCard(
                      title: "Manage Product Categories", 
                      subtitle: "Create & edit store categories (e.g. Fragrance).",
                      icon: Icons.category_outlined, 
                      color: Colors.orangeAccent,
                      onTap: () => _checkAndNavigate(context, 'manageProducts', "Product Categories", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCategoriesScreen()))),
                    ),
                    const SizedBox(height: 15),
                    _buildCMSCard(
                      title: "Manage Products", 
                      subtitle: "Update store inventory and descriptions.",
                      icon: Icons.shopping_bag, 
                      color: Colors.purpleAccent,
                      onTap: () => _checkAndNavigate(context, 'manageProducts', "Products", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminProductsScreen()))),
                    ),
                    const SizedBox(height: 15),
                    _buildCMSCard(
                      title: "Review Moderation", 
                      subtitle: "View and hide product reviews.",
                      icon: Icons.rate_review_outlined, 
                      color: Colors.yellowAccent,
                      onTap: () => _checkAndNavigate(context, 'manageProducts', "Reviews", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReviewModerationScreen()))),
                    ),
                  ],
                ),
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
