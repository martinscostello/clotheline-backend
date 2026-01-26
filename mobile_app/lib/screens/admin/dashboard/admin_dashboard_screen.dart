import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:laundry_app/widgets/glass/LiquidBackground.dart';
import 'package:laundry_app/widgets/glass/GlassContainer.dart';
import 'package:laundry_app/theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../providers/branch_provider.dart'; // [New]
import '../../../services/auth_service.dart';
import '../../../services/analytics_service.dart'; 
import '../../../services/notification_service.dart';
import '../../../utils/currency_formatter.dart';
import '../services/admin_services_screen.dart';
import '../products/admin_products_screen.dart';
import '../cms/admin_cms_content_screen.dart';
import '../notifications/admin_notification_dashboard.dart';
import '../reports/admin_financial_dashboard.dart';
import '../settings/admin_tax_settings_screen.dart';
import '../settings/admin_delivery_settings_screen.dart';
import '../orders/admin_orders_screen.dart'; 
import '../promotions/admin_promotions_screen.dart'; 

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _timeRange = 'week'; 
  String? _selectedBranchId; // [New]

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Ensure branches are loaded if not already
      Provider.of<BranchProvider>(context, listen: false).fetchBranches();
      _fetchData();
    });
  }

  void _fetchData() {
    final analytics = Provider.of<AnalyticsService>(context, listen: false);
    analytics.fetchRevenueStats(range: _timeRange, branchId: _selectedBranchId);
    analytics.fetchTopItems(limit: 5, branchId: _selectedBranchId);
  }
  
  void _onBranchChanged(String? newBranchId) {
    if (_selectedBranchId == newBranchId) return;
    setState(() => _selectedBranchId = newBranchId);
    _fetchData();
  }

  void _onRangeChanged(String newRange) {
    if (_timeRange == newRange) return;
    setState(() => _timeRange = newRange);
    _fetchData();
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
          // Branch Selector
          Consumer<BranchProvider>(
            builder: (context, branchProvider, _) {
              if (branchProvider.branches.isEmpty) return const SizedBox.shrink();
              
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    dropdownColor: const Color(0xFF2C2C2E),
                    value: _selectedBranchId,
                    hint: const Text("All Branches", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    icon: const Icon(Icons.store, color: AppTheme.secondaryColor, size: 20),
                    onChanged: _onBranchChanged,
                    items: [
                      const DropdownMenuItem<String?>(
                         value: null, 
                         child: Text("All Branches", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                      ),
                      ...branchProvider.branches.map((b) => DropdownMenuItem(
                        value: b.id,
                        child: Text(b.name, style: const TextStyle(color: Colors.white70))
                      ))
                    ],
                  ),
                ),
              );
            }
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.secondaryColor), 
            onPressed: _fetchData
          ),
          Consumer<NotificationService>(
            builder: (context, notifService, _) {
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none, color: Colors.white),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminNotificationDashboard())),
                  ),
                  if (notifService.unreadCount > 0)
                    Positioned(
                      right: 8, top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                        child: Text(
                          "${notifService.unreadCount}",
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: LiquidBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 100, bottom: 100, left: 20, right: 20),
          child: Consumer<AnalyticsService>(
            builder: (context, analytics, _) {
               if (analytics.isLoading && analytics.revenueStats == null) {
                 return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()));
               }

               final summary = analytics.revenueStats?['summary'] ?? {'total': 0, 'count': 0};
               final dataPoints = analytics.revenueStats?['data'] as List<dynamic>? ?? [];
               final topItems = analytics.topItems ?? [];

               return Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   // 1. Time Range Toggle
                   Row(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       _buildRangeToggle('week', '7 Days'),
                       const SizedBox(width: 10),
                       _buildRangeToggle('month', '30 Days'),
                       const SizedBox(width: 10),
                       _buildRangeToggle('year', 'Year'),
                     ],
                   ),
                   const SizedBox(height: 20),

                   // 2. Revenue Chart
                   GlassContainer(
                     height: 300,
                     opacity: 0.15,
                     padding: const EdgeInsets.all(20),
                     child: Column(
                       children: [
                         Row(
                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                           children: [
                             Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 const Text("Total Revenue", style: TextStyle(color: Colors.white54, fontSize: 12)),
                                 Text(
                                   CurrencyFormatter.format(summary['total']?.toDouble() ?? 0),
                                   style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                                 ),
                               ],
                             ),
                             Container(
                               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                               decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                               child: Row(
                                 children: [
                                   const Icon(Icons.arrow_upward, size: 14, color: Colors.greenAccent),
                                   Text(" ${summary['count']} Orders", style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                 ],
                               ),
                             )
                           ],
                         ),
                         const SizedBox(height: 20),
                         Expanded(child: _RevenueChart(data: dataPoints, range: _timeRange)),
                       ],
                     ),
                   ),

                   const SizedBox(height: 20),

                   // 3. Quick Actions (Same as before but condensed)
                   const Text("Quick Actions", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 15),
                   _buildQuickActionsRow(context),

                   const SizedBox(height: 30),

                   // 4. Top Products
                   const Text("Top Performers", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 10),
                   if (topItems.isEmpty)
                     const Center(child: Text("No data usually means no sales yet.", style: TextStyle(color: Colors.white38)))
                   else
                     ...topItems.map((item) {
                       final name = item['_id'] ?? "Unknown";
                       final revenue = item['totalRevenue'] ?? 0;
                       final sold = item['totalSold'] ?? 0;
                       return Padding(
                         padding: const EdgeInsets.only(bottom: 10),
                         child: GlassContainer(
                           opacity: 0.1,
                           padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                           child: Row(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: [
                               Expanded(
                                 child: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                               ),
                               Column(
                                 crossAxisAlignment: CrossAxisAlignment.end,
                                 children: [
                                   Text(CurrencyFormatter.format(revenue.toDouble()), style: const TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold)),
                                   Text("$sold Sold", style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                 ],
                               )
                             ],
                           ),
                         ),
                       );
                     }),

                   const SizedBox(height: 50),
                 ],
               );
            }
          ),
        ),
      ),
    );
  }

  Widget _buildRangeToggle(String value, String label) {
    final isSelected = _timeRange == value;
    return GestureDetector(
      onTap: () => _onRangeChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.white10,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }

  Widget _buildQuickActionsRow(BuildContext context) {
    // Condensed single row scroll
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildQuickAction(context, "Orders", Icons.list_alt, Colors.blueAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminOrdersScreen()))),
          const SizedBox(width: 15),
          _buildQuickAction(context, "Services", Icons.local_laundry_service, Colors.purpleAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminServicesScreen()))),
          const SizedBox(width: 15),
          _buildQuickAction(context, "Products", Icons.inventory_2, Colors.orangeAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminProductsScreen()))),
          const SizedBox(width: 15),
          _buildQuickAction(context, "Promos", Icons.local_offer, Colors.pinkAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPromotionsScreen()))),
           const SizedBox(width: 15),
          _buildQuickAction(context, "Reports", Icons.bar_chart, Colors.tealAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminFinancialDashboard()))),
        ],
      ),
    );
  }

  Widget _buildQuickAction(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        width: 100,
        height: 90,
        opacity: 0.1,
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _RevenueChart extends StatelessWidget {
  final List<dynamic> data;
  final String range;

  const _RevenueChart({required this.data, required this.range});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const Center(child: Text("No Data", style: TextStyle(color: Colors.white38)));

    // Max Y
    double maxY = 0;
    for (var d in data) {
      if ((d['totalRevenue'] as num) > maxY) maxY = d['totalRevenue'].toDouble();
    }
    if (maxY == 0) maxY = 100;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.2,
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
             sideTitles: SideTitles(
               showTitles: true,
               getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= data.length) return const Text('');
                  final date = DateTime.parse(data[index]['_id']);
                  String text = "${date.day}/${date.month}";
                  if (range == 'year') text = "${date.month}/${date.year}"; 
                  return SideTitleWidget(axisSide: meta.axisSide, child: Text(text, style: const TextStyle(color: Colors.white54, fontSize: 10)));
               },
             )
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
             getTooltipColor: (_) => Colors.blueGrey,
             getTooltipItem: (group, groupIndex, rod, rodIndex) {
               return BarTooltipItem(
                 CurrencyFormatter.format(rod.toY),
                 const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
               );
             }
          )
        ),
        barGroups: data.asMap().entries.map((e) {
            final index = e.key;
            final val = e.value;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: (val['totalRevenue'] as num).toDouble(),
                  color: AppTheme.primaryColor,
                  width: 12,
                  borderRadius: BorderRadius.circular(4)
                )
              ]
            );
        }).toList(),
      )
    );
  }
}
