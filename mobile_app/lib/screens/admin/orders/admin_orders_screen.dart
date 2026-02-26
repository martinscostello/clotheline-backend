import 'package:flutter/material.dart';
import 'dart:async';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/glass/GlassContainer.dart';
import '../../../../widgets/glass/LiquidBackground.dart';
import 'package:provider/provider.dart';
import '../../../../services/order_service.dart';
import '../../../../models/order_model.dart';
import 'package:intl/intl.dart';
import '../../../../models/branch_model.dart';
import '../../../../providers/branch_provider.dart';
import '../../../../utils/toast_utils.dart'; // Ensure utils imported
import 'admin_order_detail_screen.dart';
import '../../../../services/notification_service.dart';
import '../../../../utils/order_status_resolver.dart';

class AdminOrdersScreen extends StatefulWidget {
  final int initialTabIndex;
  final String? fulfillmentMode; // [NEW] logistics | deployment | bulky
  const AdminOrdersScreen({super.key, this.initialTabIndex = 0, this.fulfillmentMode});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> with SingleTickerProviderStateMixin {
  // [Multi-Branch] Filter State
  Branch? _selectedBranchFilter;
  
  // [Batch Operations]
  final Set<String> _selectedIds = {};
  bool get _isSelectionMode => _selectedIds.isNotEmpty;

  late TabController _tabController;
  Timer? _refreshTimer;
  final List<String> _tabs = ['New', 'PendingUserConfirmation', 'InProgress', 'Ready', 'Completed', 'Cancelled', 'Refunded'];
  OrderModel? _selectedOrder;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tabs.length, 
      vsync: this,
      initialIndex: widget.initialTabIndex
    );
    // Fetch orders & branches on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchOrders();
      Provider.of<BranchProvider>(context, listen: false).fetchBranches();
    });
    // Auto-refresh every 15 seconds (pause if selecting)
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted && !_isSelectionMode) _fetchOrders(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchOrders({bool silent = false}) async {
    await Provider.of<OrderService>(context, listen: false).fetchOrders(role: 'admin');
    // [Auto-Read Policy]
    if (mounted) {
       Provider.of<NotificationService>(context, listen: false).markAllReadByType('order');
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _clearSelection() {
    setState(() => _selectedIds.clear());
  }

  Future<void> _batchUpdate(String status) async {
    if (_selectedIds.isEmpty) return;
    
    // Confirm
    final confirm = await showDialog<bool>(
      context: context, 
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF202020),
        title: const Text("Confirm Batch Update", style: TextStyle(color: Colors.white)),
        content: Text("Update ${_selectedIds.length} orders to '$status'?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(child: const Text("CANCEL"), onPressed: () => Navigator.pop(ctx, false)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("UPDATE", style: TextStyle(color: Colors.black))
          )
        ],
      )
    );

    if (confirm != true) return;

    final service = Provider.of<OrderService>(context, listen: false);
    final success = await service.batchUpdateStatus(_selectedIds.toList(), status);

    if (success) {
      if (mounted) {
         ToastUtils.show(context, "Updated ${_selectedIds.length} orders", type: ToastType.success);
         _clearSelection();
      }
    } else {
      if (mounted) ToastUtils.show(context, "Batch Update Failed", type: ToastType.error);
    }
  }

  void _showBatchMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               const Text("Update Status To...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
               const SizedBox(height: 10),
               Wrap(
                 spacing: 10,
                 children: [
                   _batchActionButton("InProgress", Colors.orange),
                   _batchActionButton("Ready", Colors.purple),
                   _batchActionButton("Completed", Colors.green),
                 ],
               ),
               const SizedBox(height: 15),
               Divider(color: Colors.white.withValues(alpha: 0.1)),
               const SizedBox(height: 15),
               ListTile(
                 leading: const Icon(Icons.print, color: Colors.blueAccent),
                 title: const Text("Print Labels (Batch)", style: TextStyle(color: Colors.white)),
                 onTap: () {
                    Navigator.pop(ctx);
                    ToastUtils.show(context, "Printing ${_selectedIds.length} labels...", type: ToastType.info);
                    _clearSelection();
                 },
               ),
               const SizedBox(height: 20),
            ],
          ),
        );
      }
    );
  }

  Widget _batchActionButton(String status, Color color) {
    return ActionChip(
      label: Text(status),
      backgroundColor: color.withValues(alpha: 0.2),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
      side: BorderSide(color: color),
      onPressed: () {
        Navigator.pop(context);
        _batchUpdate(status);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: _isSelectionMode 
             ? Text("${_selectedIds.length} Selected", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
             : _buildBranchFilterTitle(),
        backgroundColor: _isSelectionMode ? AppTheme.primaryColor.withValues(alpha: 0.8) : Colors.transparent,
        elevation: 0,
        leading: _isSelectionMode 
            ? IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: _clearSelection)
            : const BackButton(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: _isSelectionMode ? Colors.white : AppTheme.primaryColor,
          unselectedLabelColor: Colors.white70,
          indicatorColor: _isSelectionMode ? Colors.white : AppTheme.primaryColor,
          tabs: _tabs.map((t) => Tab(text: t == 'PendingUserConfirmation' ? 'Pending' : t)).toList(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => Provider.of<OrderService>(context, listen: false).fetchOrders(role: 'admin'),
          )
        ],
      ),
      floatingActionButton: _isSelectionMode 
         ? Padding(
             padding: const EdgeInsets.only(bottom: 90),
             child: FloatingActionButton.extended(
               onPressed: _showBatchMenu, 
               label: const Text("Update Status"),
               icon: const Icon(Icons.edit),
               backgroundColor: AppTheme.primaryColor,
             ),
           )
         : null,
      body: LiquidBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isTablet = constraints.maxWidth >= 500; // Sidebar (100) + Content (500) = 600px Screen
            
            Widget listContent = Consumer<OrderService>(
              builder: (context, orderService, child) {
                if (orderService.orders.isEmpty) {
                  return const Center(child: Text("No orders found", style: TextStyle(color: Colors.white54)));
                }
                return child!;
              },
              child: SizedBox.expand(
                child: TabBarView(
                  controller: _tabController,
                  children: _tabs.map((status) {
                    return _AdminOrderTabContent(
                      status: status, 
                      selectedBranch: _selectedBranchFilter,
                      fulfillmentMode: widget.fulfillmentMode,
                      onFetch: _fetchOrders,
                      buildCard: _buildOrderCard,
                    );
                  }).toList(),
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
                    child: _selectedOrder == null
                        ? const Center(child: Text("Select an order to view details", style: TextStyle(color: Colors.white24)))
                        : KeyedSubtree(
                            key: ValueKey(_selectedOrder!.id),
                            child: AdminOrderDetailBody(order: _selectedOrder, isEmbedded: true),
                          ),
                  ),
                ],
              );
            }

            return listContent;
          },
        ),
      ),
    ),
  );
}

  Widget _buildBranchFilterTitle() {
    return Consumer<BranchProvider>(
       builder: (context, provider, _) {
          return DropdownButton<Branch?>(
            value: _selectedBranchFilter,
            dropdownColor: Colors.black87,
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
            underline: const SizedBox(), 
            hint: const Text("All Branches", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            items: [
              const DropdownMenuItem<Branch?>(
                value: null,
                child: Text("All Branches"), // Reset filter
              ),
              ...provider.branches.map((b) => DropdownMenuItem(
                value: b,
                child: Text(b.name),
              ))
            ],
            onChanged: (Branch? value) {
              setState(() => _selectedBranchFilter = value);
            },
          );
       }
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final isSelected = _selectedIds.contains(order.id);

    return GestureDetector(
      onLongPress: () {
        if (!_isSelectionMode) _toggleSelection(order.id);
      },
      onTap: () async {
        if (_isSelectionMode) {
          _toggleSelection(order.id);
        } else if (MediaQuery.of(context).size.width >= 600) {
          setState(() => _selectedOrder = order);
        } else {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AdminOrderDetailScreen(order: order)),
          );
          if (result == true && context.mounted) {
             _fetchOrders();
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            border: isSelected 
                ? Border.all(color: AppTheme.primaryColor, width: 2) 
                : (_selectedOrder != null && _selectedOrder?.id == order.id && MediaQuery.of(context).size.width >= 600)
                    ? Border.all(color: AppTheme.secondaryColor.withValues(alpha: 0.5), width: 2)
                    : null,
            borderRadius: BorderRadius.circular(15)
          ),
          child: GlassContainer(
            opacity: 0.1,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Padding(
              padding: const EdgeInsets.all(0),
              child: Row(
                children: [
                  // Checkbox Area (Animated)
                  if (_isSelectionMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 15),
                      child: Icon(
                        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: isSelected ? AppTheme.primaryColor : Colors.white54,
                      ),
                    ),
                    
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("#${order.id.substring(order.id.length - 6).toUpperCase()}", style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  Text(order.userName ?? order.guestName ?? "Guest", style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                                  Text(DateFormat('MMM dd, hh:mm a').format(order.date.toLocal()), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                ],
                              ),
                            ),
                            _buildStatusBadge(order),
                          ],
                        ),
                        if (order.laundryNotes != null && order.laundryNotes!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 14),
                                  SizedBox(width: 4),
                                  Text("SPECIAL CARE", style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                ],
                              ),
                            ),
                          ),
                        const Divider(color: Colors.white10, height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("${order.items.length} Items", style: const TextStyle(color: Colors.white70)),
                            Text("₦${_formatCurrency(order.totalAmount)}", style: const TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(OrderModel order) {
    final status = OrderStatusResolver.getDisplayStatus(order);
    final color = OrderStatusResolver.getStatusColor(order);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5))
      ),
      child: Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  String _formatCurrency(double amount) {
    return NumberFormat("#,##0", "en_US").format(amount);
  }
}

// Separate internal widget for tab content to allow stable rebuilds and keep-alive
class _AdminOrderTabContent extends StatefulWidget {
  final String status;
  final Branch? selectedBranch;
  final String? fulfillmentMode; // [NEW]
  final Future<void> Function() onFetch;
  final Widget Function(OrderModel) buildCard;

  const _AdminOrderTabContent({
    required this.status,
    required this.selectedBranch,
    this.fulfillmentMode,
    required this.onFetch,
    required this.buildCard,
  });

  @override
  State<_AdminOrderTabContent> createState() => _AdminOrderTabContentState();
}

class _AdminOrderTabContentState extends State<_AdminOrderTabContent> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // [FIX] Maintain tab state during horizontal swipe

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final topPadding = MediaQuery.paddingOf(context).top;
    final headerHeight = topPadding + kToolbarHeight + kTextTabBarHeight - 55; // Further reduction to push up

    return Consumer<OrderService>(
      builder: (context, orderService, _) {
        List<OrderModel> orders = orderService.orders
            .where((o) => o.status.name == widget.status || (widget.status == 'PendingUserConfirmation' && o.status.name == 'Inspecting'))
            .toList();

        if (widget.selectedBranch != null) {
          orders = orders.where((o) => o.branchId == widget.selectedBranch!.id).toList();
        }

        if (widget.fulfillmentMode != null) {
           if (widget.fulfillmentMode == 'logistics') {
             // Logistics view shows both laundry and bulky by default, OR just logistics?
             // User said: "Logistics: services in logistics and bulky (factory logistics)"
             orders = orders.where((o) => o.fulfillmentMode == 'logistics' || o.fulfillmentMode == 'bulky').toList();
           } else {
             orders = orders.where((o) => o.fulfillmentMode == widget.fulfillmentMode).toList();
           }
        }

        if (orders.isEmpty) {
          String msg = "No ${widget.status} orders";
          if (widget.selectedBranch != null) msg += " in ${widget.selectedBranch!.name}";
          return Center(child: Text(msg, style: const TextStyle(color: Colors.white30)));
        }

        return RefreshIndicator(
          onRefresh: widget.onFetch,
          color: AppTheme.primaryColor,
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true, // [FIX] Eliminate automatic top padding from ListView
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
              padding: EdgeInsets.fromLTRB(20, headerHeight, 20, 100),
              itemCount: orders.length,
              itemBuilder: (context, index) => widget.buildCard(orders[index]),
            ),
          ),
        );
      },
    );
  }
}
