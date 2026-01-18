import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:laundry_app/widgets/glass/LiquidBackground.dart';
import 'package:laundry_app/widgets/glass/GlassContainer.dart';
import 'package:laundry_app/theme/app_theme.dart';
import '../../../services/auth_service.dart';
import '../../../services/order_service.dart';
import '../../../models/order_model.dart';
import '../../../utils/currency_formatter.dart';
import '../services/admin_services_screen.dart';
import '../products/admin_products_screen.dart'; // [FIXED] Navigate to list, not add
import '../cms/admin_cms_content_screen.dart';
import '../notifications/admin_notification_dashboard.dart';
import '../reports/admin_financial_dashboard.dart';
import '../settings/admin_tax_settings_screen.dart';
import '../settings/admin_delivery_settings_screen.dart';
// import '../orders/admin_orders_screen.dart'; // If needed for 'Create Order' or linking Recent Activity

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OrderService>(context, listen: false).fetchOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Admin Dashboard", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.secondaryColor), 
            onPressed: () => Provider.of<OrderService>(context, listen: false).fetchOrders()
          ),
        ],
      ),
      body: LiquidBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 100, bottom: 100, left: 20, right: 20),
          child: Consumer<OrderService>(
            builder: (context, orderService, _) {
              final orders = orderService.orders;
            
            // Get Permissions
            final authService = Provider.of<AuthService>(context, listen: false);
            final user = authService.currentUser;
            final permissions = user != null ? (user['permissions'] ?? {}) : {};
            final isMaster = user != null && user['isMasterAdmin'] == true;

            // Calculate Stats (Client-Side)c
              final activeOrders = orders.where((o) => o.status != OrderStatus.Completed && o.status != OrderStatus.Cancelled).length;
              final pendingOrders = orders.where((o) => o.status == OrderStatus.New).length;
              final revenue = orders
                  .where((o) => o.status == OrderStatus.Completed) // Assuming only completed counts as revenue
                  .fold(0.0, (sum, o) => sum + o.totalAmount);

              // Recent Orders (Sort by date desc just in case, catch 5)
              final recentOrders = List<OrderModel>.from(orders);
              recentOrders.sort((a, b) => b.date.compareTo(a.date));
              final top5Orders = recentOrders.take(5).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats Grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: 1.4,
                    children: [
                       _buildStatCard("Active Orders", "$activeOrders", Icons.local_laundry_service, Colors.blue),
                       _buildStatCard("Pending", "$pendingOrders", Icons.pending_actions, Colors.orange),
                       _buildStatCard("Revenue", CurrencyFormatter.format(revenue), Icons.attach_money, Colors.green),
                       _buildStatCard("New Users", "N/A", Icons.person_add, Colors.purple), // Placeholder
                    ],
                  ),
                  const SizedBox(height: 30),

                  const SizedBox(height: 20),
                  const Text("Quick Actions", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        if (isMaster || permissions['manageServices'] == true)
                           _buildQuickAction(context, "Manage Services", Icons.local_laundry_service, Colors.blueAccent, () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminServicesScreen()));
                           }),
                        if ((isMaster || permissions['manageServices'] == true) && (isMaster || permissions['manageProducts'] == true || permissions['manageCMS'] == true))
                          const SizedBox(width: 15),
                        if (isMaster || permissions['manageProducts'] == true)
                           _buildQuickAction(context, "Manage Products", Icons.inventory_2, Colors.purpleAccent, () {
                               Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminProductsScreen()));
                           }),
                        if ((isMaster || permissions['manageProducts'] == true) && (isMaster || permissions['manageCMS'] == true))
                          const SizedBox(width: 15),
                        if (isMaster || permissions['manageCMS'] == true)
                           _buildQuickAction(context, "Ads & Banners", Icons.campaign, Colors.orangeAccent, () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCMSContentScreen(section: 'ads')));
                           }),
                        if (isMaster || permissions['manageUsers'] == true) ...[
                           const SizedBox(width: 15),
                           _buildQuickAction(context, "Notifications", Icons.notifications_active, Colors.pinkAccent, () {
                              // Navigator push to AdminNotificationDashboard
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminNotificationDashboard()));
                           }),
                           const SizedBox(width: 15),
                           _buildQuickAction(context, "Financial Reports", Icons.bar_chart, Colors.tealAccent, () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminFinancialDashboard()));
                           }),
                           const SizedBox(width: 15),
                           _buildQuickAction(context, "Tax & VAT", Icons.percent, Colors.indigoAccent, () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminTaxSettingsScreen()));
                           }),
                           const SizedBox(width: 15),
                           _buildQuickAction(context, "Delivery Settings", Icons.map, Colors.cyanAccent, () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDeliverySettingsScreen()));
                           }),
                        ]
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Recent Activity / Incoming Requests
                  const Text("Incoming Orders", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  
                  if (top5Orders.isEmpty)
                     const Padding(
                       padding: EdgeInsets.all(20.0),
                       child: Center(child: Text("No orders found", style: TextStyle(color: Colors.white38))),
                     )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: top5Orders.length,
                      itemBuilder: (context, index) {
                        final order = top5Orders[index];
                        final timeDiff = DateTime.now().difference(order.date);
                        String timeAgo;
                        if (timeDiff.inMinutes < 60) {
                          timeAgo = "${timeDiff.inMinutes} mins ago";
                        } else if (timeDiff.inHours < 24) {
                          timeAgo = "${timeDiff.inHours} hrs ago";
                        } else {
                          timeAgo = "${timeDiff.inDays} days ago";
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GlassContainer(
                            opacity: 0.1,
                            padding: const EdgeInsets.all(15),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.white10,
                                  radius: 18,
                                  child: Icon(_getStatusIcon(order.status), size: 18, color: Colors.white70),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("${order.guestName ?? 'User'} placed an order", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      Text(
                                        "$timeAgo • ${CurrencyFormatter.format(order.totalAmount)} • ${order.status.name}",
                                        style: TextStyle(color: _getStatusColor(order.status), fontSize: 12)
                                      ),
                                    ],
                                  ),
                                ),
                                // const Icon(Icons.chevron_right, color: Colors.white24),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                ],
              );
            }
          ),
        ),
      ),
    );
  }

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.New: return Icons.new_releases;
      case OrderStatus.InProgress: return Icons.local_laundry_service;
      case OrderStatus.Ready: return Icons.check_circle_outline;
      case OrderStatus.Completed: return Icons.done_all;
      case OrderStatus.Cancelled: return Icons.cancel;
    }
  }

  Color _getStatusColor(OrderStatus status) {
     switch (status) {
      case OrderStatus.New: return Colors.orangeAccent;
      case OrderStatus.InProgress: return Colors.blueAccent;
      case OrderStatus.Ready: return Colors.greenAccent;
      case OrderStatus.Completed: return Colors.grey;
      case OrderStatus.Cancelled: return Colors.redAccent;
    }
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return GlassContainer(
      opacity: 0.15,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 4),
          Text(title, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildQuickAction(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        width: 140,
        height: 100,
        opacity: 0.1,
        padding: const EdgeInsets.all(15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
