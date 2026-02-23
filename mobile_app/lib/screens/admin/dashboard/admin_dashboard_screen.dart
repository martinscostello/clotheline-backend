import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:laundry_app/widgets/glass/LiquidBackground.dart';
import 'package:laundry_app/widgets/glass/GlassContainer.dart';
import 'package:laundry_app/theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../providers/branch_provider.dart'; // [New]
import '../../../services/auth_service.dart';
import '../../../services/analytics_service.dart'; 
import '../../../services/notification_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/push_notification_service.dart';
import '../../../utils/currency_formatter.dart';
import '../notifications/admin_notification_dashboard.dart';
import '../notifications/admin_broadcast_screen.dart';
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
  final GlobalKey<NavigatorState> _dashboardNavigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isTablet = (width >= 600) || kIsWeb;

    if (isTablet) {
      return Navigator(
        key: _dashboardNavigatorKey,
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            builder: (context) => const AdminDashboardContent(),
            settings: settings,
          );
        },
      );
    }
    
    return const AdminDashboardContent();
  }
}

class AdminDashboardContent extends StatefulWidget {
  const AdminDashboardContent({super.key});

  @override
  State<AdminDashboardContent> createState() => _AdminDashboardContentState();
}

class _AdminDashboardContentState extends State<AdminDashboardContent> {
  String _timeRange = 'week'; 
  String? _selectedBranchId; // [New]
  String _operationsMode = 'logistics'; // [NEW] logistics | deployment
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
    analytics.fetchRevenueStats(range: _timeRange, branchId: _selectedBranchId, fulfillmentMode: _operationsMode);
    analytics.fetchTopItems(limit: 5, branchId: _selectedBranchId, fulfillmentMode: _operationsMode);
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
    final double width = MediaQuery.of(context).size.width;
    final bool isTablet = (width >= 600) || kIsWeb;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Admin Dashboard", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: PopupMenuButton<String>(
          icon: Icon(
            _operationsMode == 'logistics' ? Icons.local_shipping : Icons.engineering,
            color: AppTheme.primaryColor,
          ),
          onSelected: (mode) {
             setState(() => _operationsMode = mode);
             _fetchData();
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'logistics',
              child: Row(
                children: [
                  Icon(Icons.local_shipping, color: Colors.blueAccent),
                  SizedBox(width: 10),
                  Text("Logistics Ops"),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'deployment',
              child: Row(
                children: [
                  Icon(Icons.engineering, color: Colors.tealAccent),
                  SizedBox(width: 10),
                  Text("Field Operations"),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Branch Selector (Icon Only)
          Consumer<BranchProvider>(
            builder: (context, branchProvider, _) {
              if (branchProvider.branches.isEmpty) return const SizedBox.shrink();
              
              return Padding(
                padding: const EdgeInsets.only(right: 0.0),
                child: PopupMenuButton<String?>(
                  icon: const Icon(Icons.store, color: AppTheme.secondaryColor, size: 22),
                  color: const Color(0xFF2C2C2E),
                  tooltip: "Select Branch",
                  initialValue: _selectedBranchId,
                  onSelected: _onBranchChanged,
                  itemBuilder: (context) => [
                    const PopupMenuItem<String?>(
                       value: null, 
                       child: Text("All Branches", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                    ),
                    ...branchProvider.branches.map((b) => PopupMenuItem(
                      value: b.id,
                      child: Text(b.name, style: const TextStyle(color: Colors.white70))
                    ))
                  ],
                ),
              );
            }
          ),
          // Broadcast Icon
          IconButton(
            icon: const Icon(Icons.campaign, color: Colors.blueAccent), 
            tooltip: "Broadcast",
            onPressed: () => Navigator.of(context, rootNavigator: !isTablet).push(MaterialPageRoute(builder: (_) => const AdminBroadcastScreen())),
          ),
          // Request Web Push (Only for Web)
          if (kIsWeb)
            IconButton(
              icon: const Icon(Icons.notification_add, color: Colors.orangeAccent),
              tooltip: "Enable Web Push Notifications",
              onPressed: () async {
                // To be robustly implemented next, will trigger browser permission
                await PushNotificationService.requestWebPermission();
                if (context.mounted) {
                  await Provider.of<AuthService>(context, listen: false).syncFcmToken();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Notification prompt completed. Token synced.")));
                }
              },
            ),
          // Refresh Icon
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.secondaryColor), 
            onPressed: _fetchData
          ),
          // Notifications
          Consumer<NotificationService>(
            builder: (context, notifService, _) {
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none, color: Colors.white),
                    onPressed: () => Navigator.of(context, rootNavigator: !isTablet).push(MaterialPageRoute(builder: (_) => const AdminNotificationDashboard())),
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
          padding: const EdgeInsets.only(top: 110, left: 15, right: 15, bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dashboard Welcome
              Consumer<AuthService>(
                builder: (context, auth, _) {
                  final name = auth.currentUser?['name']?.split(' ')[0] ?? 'Admin';
                    return Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Row(
                         children: [
                           Text("Hello, $name 👋", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                           const Spacer(),
                           _buildModeChip(),
                         ],
                       ),
                       const Text("Here's what's happening today", style: TextStyle(color: Colors.white54, fontSize: 13)),
                     ],
                   );
                }
              ),
              const SizedBox(height: 15),

              // Filter Tabs (Today, Week, Month)
              _buildFilterTabs(),
              const SizedBox(height: 20),

              // Quick Actions & Metrics Check
              Consumer<AnalyticsService>(
                builder: (context, analytics, _) {
                  if (analytics.isLoading && analytics.revenueStats == null) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final summary = analytics.revenueStats?['summary'] ?? {'total': 0, 'count': 0, 'deliveryFees': 0};
                  final dataPoints = analytics.revenueStats?['data'] as List<dynamic>? ?? [];
                  
                   // Top Row Metrics (Total vs Delivery)
                   final authService = Provider.of<AuthService>(context, listen: false);
                   return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Analytics Chart (Revenue Overview)
                        const Text("Revenue Overview", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 15),
                        GlassContainer(
                          opacity: 0.1,
                          padding: const EdgeInsets.all(15),
                          child: SizedBox(
                            height: 220,
                            child: _canViewRevenue() 
                                ? _RevenueChart(data: dataPoints, range: _timeRange)
                                : const Center(child: Text("****", style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold, letterSpacing: 8))),
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Edit Quick Actions Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Quick Actions", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Larger hit area
                              ),
                              icon: Icon(_isEditMode ? Icons.check : Icons.edit, size: 20, color: AppTheme.secondaryColor),
                              label: Text(_isEditMode ? "Done" : "Edit", style: const TextStyle(color: AppTheme.secondaryColor, fontSize: 15, fontWeight: FontWeight.bold)),
                              onPressed: () {
                                setState(() {
                                  _isEditMode = !_isEditMode;
                                  if (!_isEditMode) _savePreferences(); // Save on Done
                                });
                              },
                            )
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Quick Actions Grid
                        _buildQuickActionsGrid(context),

                        const SizedBox(height: 30),

                        // Top Items
                        if (analytics.topItems != null && analytics.topItems!.isNotEmpty) ...[
                          const Text("Top Selling Items", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: analytics.topItems!.length,
                            itemBuilder: (context, index) {
                              final item = analytics.topItems![index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: GlassContainer(
                                  opacity: 0.05,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  child: ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), shape: BoxShape.circle),
                                    child: Text("#${index + 1}", style: const TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                  title: Text(item['_id'] ?? "Unknown", style: const TextStyle(color: Colors.white, fontSize: 14)),
                                  trailing: Text("${item['totalSold'] ?? 0} sold", style: const TextStyle(color: Colors.white54, fontSize: 13)),
                                  subtitle: Text(CurrencyFormatter.format((item['totalRevenue'] ?? 0).toDouble()), style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                                ),
                                ),
                              );
                            },
                          )
                        ],
                     ],
                  );
                }
              ),
            ],
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

  bool _canViewRevenue() {
    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return false;
    if (user['isMasterAdmin'] == true) return true;
    return user['permissions']?['viewRevenueOverview'] == true;
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
        buildDefaultDragHandles: true, // Native drag handles work best on web
        itemCount: _quickActions.length,
        itemBuilder: (context, index) {
          final action = _quickActions[index];
          return ListTile(
            key: ValueKey(action['id']),
            leading: Icon(action['icon'], color: action['color']),
            title: Text(action['label'], style: const TextStyle(color: Colors.white)),
            trailing: IconButton(
              icon: const Icon(Icons.edit, color: Colors.white54, size: 24), // Larger icon
              onPressed: () => _renameAction(index),
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
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: _quickActions.length,
      itemBuilder: (context, index) {
        final action = _quickActions[index];
        return _buildQuickActionCard(context, action, isTablet);
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

  Widget _buildQuickActionCard(BuildContext context, Map<String, dynamic> action, bool isTablet) {
    return _QuickActionCard(
      label: action['label'],
      icon: action['icon'],
      color: action['color'],
      onTap: () {
        switch (action['id']) {
          case 'orders':
            if (_hasPermission("Orders")) {
              Navigator.of(context, rootNavigator: !isTablet).push(MaterialPageRoute(
                builder: (_) => AdminOrdersScreen(fulfillmentMode: _operationsMode)
              ));
            }
            break;
          case 'pos':
            if (_hasPermission("Orders")) {
              Navigator.of(context, rootNavigator: !isTablet).push(MaterialPageRoute(
                builder: (_) => AdminPOSScreen(fulfillmentMode: _operationsMode)
              ));
            }
            break;
          case 'chat':
            if (_hasPermission("Reports")) Navigator.of(context, rootNavigator: !isTablet).push(MaterialPageRoute(builder: (_) => const AdminChatScreen()));
            break;
          case 'reports':
            if (_hasPermission("Reports")) {
               Navigator.of(context, rootNavigator: !isTablet).push(MaterialPageRoute(
                 builder: (_) => AdminFinancialReportsScreen(fulfillmentMode: _operationsMode)
               ));
            }
            break;
        }
      },
    );
  }

  Widget _buildModeChip() {
    final bool isLogistics = _operationsMode == 'logistics';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (isLogistics ? Colors.blue : Colors.teal).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: (isLogistics ? Colors.blue : Colors.teal).withValues(alpha: 0.5)),
      ),
      child: Text(
        isLogistics ? "LOGISTICS OPS" : "FIELD OPS",
        style: TextStyle(
          color: isLogistics ? Colors.blueAccent : Colors.tealAccent,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildTab("Today", "day"),
          const SizedBox(width: 10),
          _buildTab("This Week", "week"),
          const SizedBox(width: 10),
          _buildTab("This Month", "month"),
          const SizedBox(width: 10),
          _buildTab("This Year", "year"),
        ],
      ),
    );
  }

  Widget _buildTab(String label, String value) {
    bool selected = _timeRange == value;
    return GestureDetector(
      onTap: () => _onRangeChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.secondaryColor : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppTheme.secondaryColor : Colors.white10)
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.black : Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }

  Widget _buildMetricCard(String title, String amount, IconData icon, Color color) {
    return GlassContainer(
      opacity: 0.1,
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(amount, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditLabelDialog(int index) {
    final controller = TextEditingController(text: _quickActions[index]['label']);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text("Edit Label", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
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
                _savePreferences();
              });
              Navigator.pop(ctx);
            },
            child: const Text("SAVE", style: TextStyle(color: AppTheme.secondaryColor)),
          ),
        ],
      ),
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
