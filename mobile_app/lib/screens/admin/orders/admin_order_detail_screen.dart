import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/glass/GlassContainer.dart';
import '../../../../widgets/glass/LiquidBackground.dart';
import '../../../../models/order_model.dart';
import '../../../../services/order_service.dart';
import 'package:provider/provider.dart';
import '../../../../services/api_service.dart';
import '../../../../services/chat_service.dart'; // [FIX] Import ChatService

import 'package:url_launcher/url_launcher.dart';
import '../../../../utils/toast_utils.dart';
import '../chat/admin_chat_screen.dart'; // [FIX] Import AdminChatScreen
import '../../../../services/whatsapp_service.dart';
import '../../../../services/receipt_service.dart'; // [NEW]
import '../../../../providers/branch_provider.dart'; // [NEW]
import '../../../../models/branch_model.dart'; // [NEW]

class AdminOrderDetailScreen extends StatelessWidget {
  final OrderModel? order;
  final String? orderId;
  const AdminOrderDetailScreen({super.key, this.order, this.orderId});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(order != null ? "Order #${order!.id.substring(order!.id.length - 6).toUpperCase()}" : "Order Details", style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.transparent,
          leading: const BackButton(color: Colors.white),
        ),
        body: LiquidBackground(
          child: AdminOrderDetailBody(order: order, orderId: orderId),
        ),
      ),
    );
  }
}

class AdminOrderDetailBody extends StatefulWidget {
  final OrderModel? order;
  final String? orderId;
  final bool isEmbedded;

  const AdminOrderDetailBody({super.key, this.order, this.orderId, this.isEmbedded = false});

  @override
  State<AdminOrderDetailBody> createState() => _AdminOrderDetailBodyState();
}

class _AdminOrderDetailBodyState extends State<AdminOrderDetailBody> {
  OrderModel? _order;
  bool _isLoading = true;
  late String _currentStatus;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    if (widget.order != null) {
      _order = widget.order;
      _currentStatus = _order!.status.name;
      _isLoading = false;
    } else if (widget.orderId != null) {
      _fetchOrder();
    } else {
      _isLoading = false; // Should not happen
    }
  }

  Future<void> _fetchOrder() async {
    final service = Provider.of<OrderService>(context, listen: false);
    final fetched = await service.getOrderById(widget.orderId!);
    if (mounted) {
      setState(() {
        _order = fetched;
        if (_order != null) _currentStatus = _order!.status.name;
        _isLoading = false;
      });
    }
  }

  // ... Update Status & Contact methods ...

  Future<void> _updateStatus(String newStatus) async {
    if (_order == null) return;
    setState(() => _isUpdating = true);
    final success = await Provider.of<OrderService>(context, listen: false).updateStatus(_order!.id, newStatus);
    setState(() => _isUpdating = false);
    
    if (success) {
      setState(() => _currentStatus = newStatus);
      if (mounted) ToastUtils.show(context, "Status updated to $newStatus", type: ToastType.success);
    } else {
      if (mounted) ToastUtils.show(context, "Failed to update status", type: ToastType.error);
    }
  }

  Future<void> _contactCustomer() async {
    if (_order == null) return;
    
    // [FIX] Open Admin Chat Context instead of User Chat
    final chatService = Provider.of<ChatService>(context, listen: false);
    final String? userId = _order!.userId;
    final String branchId = _order!.branchId ?? "default"; // Fallback?

    if (userId == null) {
      ToastUtils.show(context, "Cannot chat with Guest User (Email Only)", type: ToastType.warning);
      return;
    }

    ToastUtils.show(context, "Locating chat thread...", type: ToastType.info);
    final threadId = await chatService.getAdminThreadForUser(userId, branchId);
    
    if (!mounted) return;

    if (threadId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AdminChatScreen(initialThreadId: threadId)),
      );
    } else {
      ToastUtils.show(context, "No existing chat found for this user.", type: ToastType.info);
      // Option: Create thread? Admin usually responds to inbound. 
      // User must initiate? Or we can force create?
      // Backend GET / creates if not exists.
      // But Admin GET /admin/threads only lists existing.
      // We'll leave it as "No chat found" for now.
    }
  }

  Future<void> _reportIssue() async {
    OrderExceptionStatus selected = OrderExceptionStatus.Stain;
    final noteCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF202020),
          title: const Text("Report Order Issue", style: TextStyle(color: Colors.redAccent)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Select the issue type (User will be notified):", style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 15),
              DropdownButton<OrderExceptionStatus>(
                dropdownColor: const Color(0xFF333333),
                value: selected,
                isExpanded: true,
                style: const TextStyle(color: Colors.white),
                underline: Container(height: 1, color: Colors.white24),
                items: OrderExceptionStatus.values
                    .where((e) => e != OrderExceptionStatus.None)
                    .map((e) => DropdownMenuItem(value: e, child: Text(e.name))).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selected = val);
                },
              ),
              const SizedBox(height: 15),
              TextField(
                controller: noteCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Details (Optional)",
                  labelStyle: TextStyle(color: Colors.white54),
                  hintText: "e.g., Stain found on white shirt",
                  hintStyle: TextStyle(color: Colors.white24),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                ),
              )
            ],
          ),
          actions: [
            TextButton(child: const Text("CANCEL"), onPressed: () => Navigator.pop(ctx)),
            TextButton(
              child: const Text("REPORT & NOTIFY", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() => _isUpdating = true);
                final success = await Provider.of<OrderService>(context, listen: false)
                    .updateExceptionStatus(_order!.id, selected, noteCtrl.text);
                
                if (success) {
                  // _fetchOrder(); // Service usually refreshes list, but we might need re-fetch single
                  await _fetchOrder();
                }
                
                setState(() => _isUpdating = false);
                if (mounted) ToastUtils.show(context, success ? "Issue Reported" : "Failed to report", type: success ? ToastType.success : ToastType.error);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _overrideFee() async {
    final feeCtrl = TextEditingController(text: _order!.deliveryFee.toStringAsFixed(0));
    
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF202020),
        title: const Text("Override Delivery Fee", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _order!.paymentStatus == PaymentStatus.Paid 
                ? "This order is already PAID. Increasing the fee will PAUSE the order and require customer confirmation."
                : "This will update the total amount of the order and notify the customer.",
              style: TextStyle(
                color: _order!.paymentStatus == PaymentStatus.Paid ? Colors.orangeAccent : Colors.white70,
                fontSize: 13,
                fontWeight: _order!.paymentStatus == PaymentStatus.Paid ? FontWeight.bold : FontWeight.normal
              )
            ),
            const SizedBox(height: 15),
            TextField(
              controller: feeCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "New Delivery Fee",
                labelStyle: TextStyle(color: Colors.white54),
                prefixText: "₦ ",
                prefixStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              ),
            )
          ],
        ),
        actions: [
          TextButton(child: const Text("CANCEL"), onPressed: () => Navigator.pop(ctx)),
          TextButton(
            child: const Text("OVERRIDE", style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
            onPressed: () async {
              final double? newFee = double.tryParse(feeCtrl.text);
              if (newFee == null) {
                ToastUtils.show(context, "Invalid Amount", type: ToastType.error);
                return;
              }
              Navigator.pop(ctx);
              setState(() => _isUpdating = true);
              final success = await Provider.of<OrderService>(context, listen: false)
                  .overrideDeliveryFee(_order!.id, newFee);
              
              if (success) {
                await _fetchOrder();
              }
              
              setState(() => _isUpdating = false);
              if (mounted) ToastUtils.show(context, success ? "Fee Overridden" : "Failed to override", type: success ? ToastType.success : ToastType.error);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Order Not Found"), backgroundColor: Colors.transparent),
        body: const Center(child: Text("Order not found or deleted")),
      );
    }

    final topPadding = MediaQuery.paddingOf(context).top;
    // [FIX] Reduce top padding for tablet mode to remove wasted space
    final headerHeight = topPadding + kToolbarHeight + kTextTabBarHeight - 40;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, widget.isEmbedded ? headerHeight : 100, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
              // [NEW] Payment Pending Banner for POD/Manual
              if (_order!.paymentStatus == PaymentStatus.Pending && _order!.paymentMethod != 'paystack')
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.payment, color: Colors.amber),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "PAYMENT PENDING",
                          style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                        ),
                      ),
                    ],
                  ),
                ),

              // 0. Exception Banner
              if (_order!.exceptionStatus != OrderExceptionStatus.None)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.report_problem, color: Colors.redAccent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Issue: ${_order!.exceptionStatus.name}", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                            if (_order!.exceptionNote != null && _order!.exceptionNote!.isNotEmpty)
                              Text(_order!.exceptionNote!, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check_circle_outline, color: Colors.greenAccent),
                        tooltip: "Resolve Issue",
                        onPressed: () async {
                           // Resolve
                           await Provider.of<OrderService>(context, listen: false)
                              .updateExceptionStatus(_order!.id, OrderExceptionStatus.None, null);
                           _fetchOrder();
                        },
                      )
                    ],
                  ),
                ),

              // 1. Status Manager
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                child: GlassContainer(
                  opacity: 0.1,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Order Status", style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            DropdownButton<String>(
                              dropdownColor: const Color(0xFF202020),
                              value: _currentStatus,
                              style: const TextStyle(color: Colors.white),
                              underline: Container(height: 1, color: AppTheme.primaryColor),
                              onChanged: _isUpdating ? null : (val) {
                                if (val != null && val != _currentStatus) _updateStatus(val);
                              },
                              items: _getAvailableStatuses().map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s),
                              )).toList(),
                            ),
                            if (_isUpdating) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),


              // 2. Customer Info
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                child: GlassContainer(
                  opacity: 0.1,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Row(
                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                           children: [
                             const Text("Customer Info", style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                             IconButton(
                               icon: const Icon(Icons.chat_bubble_outline, color: AppTheme.primaryColor),
                                onPressed: _contactCustomer,
                                tooltip: "Message User",
                             ),
                             IconButton(
                                icon: const Icon(Icons.picture_as_pdf, color: Colors.green),
                                onPressed: () {
                                  if (_order!.guestPhone != null) {
                                    final branchName = Provider.of<BranchProvider>(context, listen: false)
                                        .branches
                                        .firstWhere((b) => b.id == _order!.branchId, orElse: () => Branch(id: '', name: 'Benin', address: '', phone: '', location: BranchLocation(lat: 0, lng: 0), deliveryZones: []))
                                        .name;
                                    
                                    ReceiptService.shareReceiptFromOrder(_order!, branchName);
                                  } else {
                                    ToastUtils.show(context, "No phone number available", type: ToastType.error);
                                  }
                                },
                                tooltip: "Share Receipt (WhatsApp)",
                              ),
                              IconButton(
                                icon: const Icon(Icons.chat_outlined, color: Colors.green),
                                onPressed: () {
                                  if (_order!.guestPhone != null) {
                                    final branchName = Provider.of<BranchProvider>(context, listen: false)
                                        .branches
                                        .firstWhere((b) => b.id == _order!.branchId, orElse: () => Branch(id: '', name: 'Benin', address: '', phone: '', location: BranchLocation(lat: 0, lng: 0), deliveryZones: []))
                                        .name;
                                    
                                    WhatsAppService.sendOrderUpdate(
                                      phone: _order!.guestPhone!,
                                      orderNumber: _order!.id,
                                      amount: _order!.totalAmount,
                                      status: _order!.status.name,
                                      guestName: _order!.guestName ?? _order!.userName,
                                      branchName: branchName,
                                    );
                                  } else {
                                    ToastUtils.show(context, "No phone number available", type: ToastType.error);
                                  }
                                },
                                tooltip: "Send WhatsApp Update",
                              )
                            ],
                          ),
                        const SizedBox(height: 5),
                        _buildInfoRow(Icons.person, _order!.userName ?? _order!.guestName ?? "Guest"),
                        _buildInfoRow(Icons.email, _order!.userEmail ?? _order!.guestEmail ?? "No Email"),
                        _buildInfoRow(Icons.phone, _order!.guestPhone ?? "No Phone"),
                        
                        const SizedBox(height: 10),
                        const Divider(color: Colors.white10),
                        const SizedBox(height: 10),
                        
                        const Text("Logistics", style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 5),
                        _buildInfoRow(Icons.upload, "Pickup: ${_order!.pickupOption}"),
                        if (_order!.pickupOption == 'Pickup') _buildInfoRow(Icons.location_on, _order!.pickupAddress ?? "N/A", isSmall: true),
                        const SizedBox(height: 10),
                        _buildInfoRow(Icons.download, "Delivery: ${_order!.deliveryOption}"),
                         if (_order!.deliveryOption == 'Deliver') _buildInfoRow(Icons.location_on, _order!.deliveryAddress ?? "N/A", isSmall: true),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Items Breakdown
              const Text("Items Breakdown", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              

              _buildGroupedItemsList(),

              const SizedBox(height: 30),

              // [NEW] Special Care / Notes
              _buildSpecialCareNotes(),

              const SizedBox(height: 30),

              // 4. Totals
              GlassContainer(
                opacity: 0.1,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                       Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Payment Status", style: TextStyle(color: Colors.white70, fontSize: 14)),
                           Text(_order!.paymentStatus.name.toUpperCase(), 
                            style: TextStyle(
                              color: _order!.paymentStatus == PaymentStatus.Paid ? Colors.green : Colors.orange, 
                              fontWeight: FontWeight.bold,
                              fontSize: 14
                            )
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildSummaryRow("Subtotal", _order!.subtotal),
                      if (_order!.pickupFee > 0) _buildSummaryRow("Pickup Fee", _order!.pickupFee),
                      if (_order!.deliveryFee > 0) _buildSummaryRow("Delivery Fee", _order!.deliveryFee),
                      if (_order!.discountAmount > 0) _buildSummaryRow("Discount", -_order!.discountAmount, color: Colors.green),
                      if (_order!.taxAmount > 0) _buildSummaryRow("VAT (${_order!.taxRate.toStringAsFixed(0)}%)", _order!.taxAmount),
                      const Divider(color: Colors.white10, height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Total Amount", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text("₦${_order!.totalAmount.toStringAsFixed(0)}", style: const TextStyle(color: AppTheme.secondaryColor, fontSize: 22, fontWeight: FontWeight.bold)),
                              if (_order!.isFeeOverridden)
                                const Text("(Fee Overridden)", style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                      if (_order!.deliveryOption == 'Deliver') ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            icon: const Icon(Icons.edit_road, size: 16),
                            label: const Text("Adjust Delivery Fee"),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white70,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 30),
                              alignment: Alignment.centerRight
                            ),
                            onPressed: _overrideFee,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Action Buttons
              Row(
                children: [
                   Expanded(
                     child: SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.secondaryColor.withValues(alpha: 0.2),
                            foregroundColor: AppTheme.secondaryColor,
                            side: const BorderSide(color: AppTheme.secondaryColor),
                          ),
                          icon: const Icon(Icons.print),
                          label: const Text("PRINT RECEIPT"),
                          onPressed: () {
                            final branchName = Provider.of<BranchProvider>(context, listen: false)
                                .branches
                                .firstWhere((b) => b.id == _order!.branchId, orElse: () => Branch(id: '', name: 'Benin', address: '', phone: '', location: BranchLocation(lat: 0, lng: 0), deliveryZones: []))
                                .name;
                            ReceiptService.printReceiptFromOrder(_order!, branchName);
                          },
                        ),
                     ),
                   ),
                   if (_order!.paymentStatus == PaymentStatus.Paid) ...[
                     const SizedBox(width: 15),
                     Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.withValues(alpha: 0.2),
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                            ),
                            icon: const Icon(Icons.undo),
                            label: const Text("REFUND"), // Shortened for space
                            onPressed: () => _showRefundDialog(),
                          ),
                        ),
                     ),
                   ],
                ],
              ),
              
              const SizedBox(height: 50),
            ],
          ),
    );
  }

  Widget _buildGroupedItemsList() {
    // 1. Group Items
    Map<String, List<OrderItem>> serviceGroups = {};
    List<OrderItem> products = [];

    for (var item in _order!.items) {
      if (item.itemType == 'Service') {
        final type = item.serviceType ?? "General";
        if (!serviceGroups.containsKey(type)) serviceGroups[type] = [];
        serviceGroups[type]!.add(item);
      } else {
        products.add(item);
      }
    }

    List<Widget> children = [];

    // 2. Render Services by Group
    for (var entry in serviceGroups.entries) {
       final serviceType = entry.key;
       final items = entry.value;

       // Header (Optional, user format implies just listing items then discount)
       // Let's render items
       children.addAll(items.map((item) => _buildItemTile(item)));
       
       // Check Discount
       final discountKey = "Discount ($serviceType)";
       if (_order!.discountBreakdown.containsKey(discountKey)) {
          final amt = _order!.discountBreakdown[discountKey]!;
          if (amt > 0) {
             children.add(_buildDiscountRow(discountKey, amt));
          }
       }
    }

    // 3. Render Store Products
    if (products.isNotEmpty) {
       children.addAll(products.map((item) => _buildItemTile(item)));
       
       // Store Discount (Global or Promo)
       if (_order!.storeDiscount > 0) {
          children.add(_buildDiscountRow("Store Discount", _order!.storeDiscount));
       }
    }
    
    // Fallback: If legacy order without breakdown but has discountAmount
    if (_order!.discountBreakdown.isEmpty && _order!.storeDiscount == 0 && _order!.discountAmount > 0) {
       children.add(_buildDiscountRow("Discount (Legacy)", _order!.discountAmount));
    }

    return Column(children: children);
  }

  Widget _buildItemTile(OrderItem item) {
    return Card(
      color: Colors.white10,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(
          item.itemType == 'Service' ? Icons.local_laundry_service : Icons.shopping_bag,
          color: item.itemType == 'Service' ? Colors.blueAccent : Colors.pinkAccent
        ),
        title: Text(item.name, style: const TextStyle(color: Colors.white)),
        subtitle: Text(
          item.itemType == 'Product' ? "Variant: ${item.variant ?? 'Standard'}" : "Service: ${item.serviceType}",
          style: const TextStyle(color: Colors.white54)
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text("x${item.quantity}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Text("₦${(item.price * item.quantity).toStringAsFixed(0)}", style: const TextStyle(color: AppTheme.secondaryColor, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscountRow(String label, double amount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15, left: 10, right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8)
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          Text("-₦${amount.toStringAsFixed(0)}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, {bool isSmall = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white54, size: 16),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: Colors.white, fontSize: isSmall ? 13 : 14))),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {Color color = Colors.white70}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 13)),
          Text("₦${amount.toStringAsFixed(0)}", style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  List<String> _getAvailableStatuses() {
    final all = ["New", "InProgress", "Ready", "Completed", "Cancelled", "Refunded"];
    if (_currentStatus == 'Refunded') return ['Refunded'];
    if (_currentStatus == 'Cancelled') return ['Cancelled'];
    
    // Admins can move forward through the lifecycle or Cancel
    List<String> valid = [_currentStatus, "Cancelled"];
    
    if (_currentStatus == 'New') valid.add("InProgress");
    if (_currentStatus == 'InProgress') valid.add("Ready");
    if (_currentStatus == 'Ready') valid.add("Completed");
    
    return all.where((s) => valid.contains(s) || s == _currentStatus).toSet().toList();
  }

  void _showRefundDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return _RefundDialog(
          order: _order!, 
          onRefundComplete: (bool success) {
            if (success) {
              setState(() => _currentStatus = 'Refunded');
              _fetchOrder(); // Refresh to see split results if partial
            }
          }
        );
      },
    );
  }

  Widget _buildSpecialCareNotes() {
    final notes = _order!.laundryNotes;
    final hasNotes = notes != null && notes.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              hasNotes ? Icons.report_problem_rounded : Icons.info_outline,
              color: hasNotes ? Colors.orange : Colors.white38,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              "SPECIAL CARE / NOTES",
              style: TextStyle(
                color: hasNotes ? Colors.orange : Colors.white38,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GlassContainer(
          opacity: 0.1,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasNotes ? notes : "No special care notes from customer",
                  style: TextStyle(
                    color: hasNotes ? Colors.white : Colors.white38,
                    fontSize: 14,
                    height: 1.5,
                    fontStyle: hasNotes ? FontStyle.normal : FontStyle.italic,
                  ),
                ),
                if (hasNotes && notes.length > 200) ...[
                   const SizedBox(height: 10),
                   TextButton(
                    onPressed: () => _showFullNotes(notes),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      "READ FULL INSTRUCTIONS",
                      style: TextStyle(color: AppTheme.primaryColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showFullNotes(String notes) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Special Care Instructions", style: TextStyle(color: Colors.orange)),
        content: SingleChildScrollView(
          child: Text(
            notes,
            style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CLOSE", style: TextStyle(color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );
  }
}

class _RefundDialog extends StatefulWidget {
  final OrderModel order;
  final Function(bool) onRefundComplete;

  const _RefundDialog({required this.order, required this.onRefundComplete});

  @override
  State<_RefundDialog> createState() => _RefundDialogState();
}

class _RefundDialogState extends State<_RefundDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _selectedItemIds = {};
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF202020),
      title: const Text("Refund Order", style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TabBar(
              controller: _tabController,
              indicatorColor: Colors.redAccent,
              labelColor: Colors.redAccent,
              unselectedLabelColor: Colors.white54,
              tabs: const [Tab(text: "FULL REFUND"), Tab(text: "PARTIAL SPLIT")],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 300,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFullRefundView(),
                  _buildPartialRefundView(),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (!_isProcessing)
          TextButton(
            child: const Text("CANCEL"),
            onPressed: () => Navigator.pop(context),
          ),
        if (_isProcessing)
          const Center(child: CircularProgressIndicator(color: Colors.redAccent))
        else
          TextButton(
            child: const Text("PROCESS REFUND", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            onPressed: _processRefund,
          )
      ],
    );
  }

  Widget _buildFullRefundView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
        const SizedBox(height: 16),
        const Text(
          "This will refund the ENTIRE amount and mark the order as Cancelled.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 16),
        Text(
          "Total: ₦${widget.order.totalAmount.toStringAsFixed(0)}",
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildPartialRefundView() {
    double refundTotal = 0;
    for (var item in widget.order.items) {
      if (_selectedItemIds.contains(item.id)) {
        refundTotal += (item.price * item.quantity);
      }
    }

    return Column(
      children: [
        const Text(
          "Select items to refund. These items will be moved to a 'Refunded' order.",
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.builder(
            itemCount: widget.order.items.length,
            itemBuilder: (context, index) {
              final item = widget.order.items[index];
              final isSelected = _selectedItemIds.contains(item.id);
              
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: Colors.redAccent,
                side: const BorderSide(color: Colors.white24),
                title: Text(item.name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                subtitle: Text("₦${item.price} x ${item.quantity}", style: const TextStyle(color: Colors.white38)),
                value: isSelected,
                onChanged: (val) {
                  if (item.id == null) return;
                  setState(() {
                    if (val == true) {
                      _selectedItemIds.add(item.id!);
                    } else {
                      _selectedItemIds.remove(item.id!);
                    }
                  });
                },
              );
            },
          ),
        ),
        const Divider(color: Colors.white24),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Refund Total:", style: TextStyle(color: Colors.white70)),
              Text("₦${refundTotal.toStringAsFixed(0)}", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ],
          ),
        )
      ],
    );
  }

  Future<void> _processRefund() async {
    setState(() => _isProcessing = true);
    final api = ApiService();
    bool success = false;

    try {
      if (_tabController.index == 0) {
        // Full Refund
        await api.client.post('/payments/refund', data: {
          'orderId': widget.order.id,
        });
        if (mounted) ToastUtils.show(context, "Full Refund Initiated", type: ToastType.success);
        success = true;
      } else {
        // Partial Refund
        if (_selectedItemIds.isEmpty) {
          ToastUtils.show(context, "Select at least one item", type: ToastType.warning);
          setState(() => _isProcessing = false);
          return;
        }

        await api.client.post('/payments/refund-partial', data: {
          'orderId': widget.order.id,
          'refundedItemIds': _selectedItemIds.toList()
        });
        if (mounted) ToastUtils.show(context, "Partial Refund & Split Successful", type: ToastType.success);
        success = true;
      }
    } catch (e) {
      if (mounted) ToastUtils.show(context, "Refund Failed: $e", type: ToastType.error);
    }

    if (mounted) {
      Navigator.pop(context);
      if (success) widget.onRefundComplete(true);
    }
  }
}
