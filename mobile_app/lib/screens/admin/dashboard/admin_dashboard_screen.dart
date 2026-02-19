import 'dart:convert';
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
import '../notifications/admin_notification_dashboard.dart';
import '../reports/admin_financial_reports_screen.dart';
import '../orders/admin_orders_screen.dart'; 
import '../pos/admin_pos_screen.dart';
import '../chat/admin_chat_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _timeRange = 'week'; 
  String? _selectedBranchId; // [New]
  bool _isEditMode = false;
  List<Map<String, dynamic>> _quickActions = [];

  final List<Map<String, dynamic>> _defaultActions = [
    {'id': 'pos', 'label': 'POS', 'icon': Icons.point_of_sale, 'color': Colors.greenAccent},
    {'id': 'orders', 'label': 'Orders', 'icon': Icons.list_alt, 'color': Colors.blueAccent},
    {'id': 'chat', 'label': 'Chat', 'icon': Icons.chat_bubble_outline, 'color': Colors.purpleAccent},
    {'id': 'reports', 'label': 'Reports', 'icon': Icons.bar_chart, 'color': Colors.tealAccent},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Ensure branches are loaded if not already
      Provider.of<BranchProvider>(context, listen: false).fetchBranches();
      await _loadPreferences();
      _fetchData();
    });
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final String? orderJson = prefs.getString('admin_quick_actions_order');
    final String? labelsJson = prefs.getString('admin_quick_actions_labels');

    List<String> order = orderJson != null ? List<String>.from(jsonDecode(orderJson)) : [];
    Map<String, String> labels = labelsJson != null ? Map<String, String>.from(jsonDecode(labelsJson)) : {};

    List<Map<String, dynamic>> actions = [];
    
    // Use saved order if exists, else default
    if (order.isNotEmpty) {
      for (var id in order) {
        final def = _defaultActions.firstWhere((a) => a['id'] == id, orElse: () => _defaultActions[0]);
        actions.add({
          ...def,
          'label': labels[id] ?? def['label'],
        });
      }
      // Add any new defaults that might not be in saved order
      for (var def in _defaultActions) {
        if (!order.contains(def['id'])) {
          actions.add({...def});
        }
      }
    } else {
      for (var def in _defaultActions) {
        actions.add({...def});
      }
    }

    setState(() => _quickActions = actions.take(4).toList());
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final order = _quickActions.map((a) => a['id']).toList();
    final Map<String, String> labels = {for (var a in _quickActions) a['id']: a['label']};

    await prefs.setString('admin_quick_actions_order', jsonEncode(order));
    await prefs.setString('admin_quick_actions_labels', jsonEncode(labels));
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
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + kToolbarHeight + 2, 
              bottom: 100, left: 20, right: 20
            ),
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
                                 decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
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
                     // 3. Quick Actions Redesign
                     Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         const Text("Quick Actions", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                         if (context.read<AuthService>().currentUser?['isMasterAdmin'] == true)
                           IconButton(
                             icon: Icon(_isEditMode ? Icons.check_circle : Icons.edit, color: AppTheme.secondaryColor, size: 20),
                             onPressed: () {
                               setState(() => _isEditMode = !_isEditMode);
                               if (!_isEditMode) _savePreferences();
                             },
                           ),
                       ],
                     ),
                     const SizedBox(height: 15),
                     _buildQuickActionsGrid(context),

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
              },
            ),
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

  bool _hasPermission(String feature) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return false;
    if (user['isMasterAdmin'] == true) return true;

    final permissions = user['permissions'] ?? {};
    bool allowed = false;

    switch (feature) {
      case 'Orders':
        allowed = permissions['manageOrders'] == true;
        break;
      case 'Services':
        allowed = permissions['manageServices'] == true;
        break;
      case 'Products':
        allowed = permissions['manageProducts'] == true;
        break;
      case 'Promos':
        allowed = permissions['manageCMS'] == true;
        break;
      case 'Reports':
        allowed = permissions['manageFinancials'] == true;
        break;
      default:
        allowed = true;
    }

    if (!allowed) {
      _showDeniedDialog(feature);
      auth.logPermissionViolation(feature);
    }
    return allowed;
  }

  void _showDeniedDialog(String feature) {
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

  Widget _buildQuickActionsGrid(BuildContext context) {
    if (_quickActions.isEmpty) return const SizedBox.shrink();

    // Responsive cross axis count: 2 for mobile, 4 for tablet (> 600px)
    final bool isTablet = MediaQuery.of(context).size.width >= 600;
    
    if (_isEditMode) {
      return ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _quickActions.length,
        itemBuilder: (context, index) {
          final action = _quickActions[index];
          return ListTile(
            key: ValueKey(action['id']),
            leading: Icon(action['icon'], color: action['color']),
            title: Text(action['label'], style: const TextStyle(color: Colors.white)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white54, size: 18),
                  onPressed: () => _renameAction(index),
                ),
                const Icon(Icons.drag_handle, color: Colors.white54),
              ],
            ),
          );
        },
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) newIndex -= 1;
            final item = _quickActions.removeAt(oldIndex);
            _quickActions.insert(newIndex, item);
          });
        },
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isTablet ? 4 : 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: isTablet ? 1.5 : 1.1,
      ),
      itemCount: _quickActions.length,
      itemBuilder: (context, index) {
        final action = _quickActions[index];
        return _buildQuickActionCard(context, action);
      },
    );
  }

  void _renameAction(int index) {
    final TextEditingController controller = TextEditingController(text: _quickActions[index]['label']);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text("Rename Action", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: "New Name",
            labelStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          TextButton(
            onPressed: () {
              setState(() {
                _quickActions[index]['label'] = controller.text;
              });
              Navigator.pop(ctx);
            },
            child: const Text("SAVE", style: TextStyle(color: AppTheme.secondaryColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(BuildContext context, Map<String, dynamic> action) {
    return _QuickActionCard(
      label: action['label'],
      icon: action['icon'],
      color: action['color'],
      onTap: () {
        switch (action['id']) {
          case 'orders':
            if (_hasPermission("Orders")) Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminOrdersScreen()));
            break;
          case 'pos':
            if (_hasPermission("Orders")) Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPOSScreen()));
            break;
          case 'chat':
            if (_hasPermission("Reports")) Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminChatScreen()));
            break;
          case 'reports':
            if (_hasPermission("Reports")) Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminFinancialReportsScreen()));
            break;
        }
      },
    );
  }
}

class _QuickActionCard extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: GlassContainer(
          opacity: 0.1,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: Icon(widget.icon, color: widget.color, size: 22),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.label, 
                  textAlign: TextAlign.center, 
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
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
