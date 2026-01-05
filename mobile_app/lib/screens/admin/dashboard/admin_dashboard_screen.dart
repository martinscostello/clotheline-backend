import 'package:flutter/material.dart';
import 'package:laundry_app/widgets/glass/LiquidBackground.dart';
import 'package:laundry_app/widgets/glass/GlassContainer.dart';
import 'package:laundry_app/theme/app_theme.dart';
import '../services/admin_services_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Admin Dashboard", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.notifications_active, color: AppTheme.secondaryColor), onPressed: () {}),
        ],
      ),
      body: LiquidBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 100, bottom: 100, left: 20, right: 20),
          child: Column(
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
                   _buildStatCard("Active Orders", "12", Icons.local_laundry_service, Colors.blue),
                   _buildStatCard("Pending", "5", Icons.pending_actions, Colors.orange),
                   _buildStatCard("Revenue", "₦1,240", Icons.attach_money, Colors.green),
                   _buildStatCard("New Users", "8", Icons.person_add, Colors.purple),
                ],
              ),
              const SizedBox(height: 30),

              // Quick Actions
              const Text("Quick Actions", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildQuickAction(context, "Manage Service Categories", Icons.category, Colors.blueGrey, () {
                       Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminServicesScreen()));
                    }),
                    const SizedBox(width: 15),
                    _buildQuickAction(context, "Add Product", Icons.add_shopping_cart, Colors.purpleAccent, () {
                      // Placeholder for Add Product
                    }),
                    const SizedBox(width: 15),
                    _buildQuickAction(context, "Create Order", Icons.add_circle_outline, Colors.orangeAccent, () {
                      // Placeholder for Create Order
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Recent Activity / Incoming Requests
              const Text("Incoming Requests", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 5,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GlassContainer(
                      opacity: 0.1,
                      padding: const EdgeInsets.all(15),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.white10,
                            child: Text("${index + 1}", style: const TextStyle(color: Colors.white)),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("User #${200 + index} placed an order", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                const Text("2 mins ago • Pickup Req", style: TextStyle(color: Colors.white54, fontSize: 12)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.white24),
                        ],
                      ),
                    ),
                  );
                },
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return GlassContainer(
      opacity: 0.15,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
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
              decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
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
