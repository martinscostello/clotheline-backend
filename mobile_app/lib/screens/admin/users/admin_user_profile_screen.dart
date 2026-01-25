import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/glass/GlassContainer.dart';
import '../../../../widgets/glass/LiquidBackground.dart';
import '../../../../models/order_model.dart';
import '../../../../services/order_service.dart';
import 'package:provider/provider.dart';
import '../../../../services/chat_service.dart';
// import '../../../../screens/user/chat/chat_screen.dart'; // [Removed]
import '../orders/admin_order_detail_screen.dart';
import 'package:laundry_app/utils/toast_utils.dart';
import '../chat/admin_chat_screen.dart'; // [New]
import '../../../../services/auth_service.dart';

class AdminUserProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const AdminUserProfileScreen({super.key, required this.user});

  @override
  State<AdminUserProfileScreen> createState() => _AdminUserProfileScreenState();
}

class _AdminUserProfileScreenState extends State<AdminUserProfileScreen> {
  List<OrderModel> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    final userId = widget.user['_id'].toString();
    final orders = await Provider.of<OrderService>(context, listen: false).fetchOrdersByUser(userId);
    if (mounted) {
      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    }
  }

  Future<void> _showDeleteConfirm(BuildContext context) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = widget.user['_id'];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Delete User Account?", style: TextStyle(color: Colors.white)),
        content: const Text("This action is permanent and will remove all user data. Proceed?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
               Navigator.pop(ctx);
               ToastUtils.show(context, "Deleting user...", type: ToastType.info);
               final success = await authService.deleteUser(userId);
               
               if (context.mounted) {
                 if (success) {
                   ToastUtils.show(context, "User deleted successfully", type: ToastType.success);
                   Navigator.pop(context); // Go back to list
                 } else {
                   ToastUtils.show(context, "Delete failed. User may have existing dependencies.", type: ToastType.error);
                 }
               }
            },
            child: const Text("Delete"),
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final totalSpent = _orders.fold(0.0, (sum, o) => sum + o.totalAmount);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("User Profile", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        leading: const BackButton(color: Colors.white),
      ),
      body: LiquidBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 100, 20, 20),
          child: Column(
             children: [
               // 1. Profile Header
               GlassContainer(
                 child: Padding(
                   padding: const EdgeInsets.all(20),
                   child: Column(
                     children: [
                       CircleAvatar(
                         radius: 40,
                         backgroundColor: Colors.white24,
                         child: Text(
                           user['name'].toString().substring(0, 1).toUpperCase(),
                           style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
                         ),
                       ),
                       const SizedBox(height: 15),
                       Text(user['name'], style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                       Text(user['email'], style: const TextStyle(color: Colors.white70)),
                       if (user['phone'] != null) Text(user['phone'], style: const TextStyle(color: Colors.white54)),
                       
                       const SizedBox(height: 20),
                       Row(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.black,
                              ),
                              icon: const Icon(Icons.chat),
                              label: const Text("CHAT"),
                              onPressed: () async {
                                final chatService = Provider.of<ChatService>(context, listen: false);
                                final userId = user['_id'];
                                final branchId = user['branchId'] ?? "default"; 

                                ToastUtils.show(context, "Locating chat...", type: ToastType.info);
                                final threadId = await chatService.getAdminThreadForUser(userId, branchId);

                                if (!context.mounted) return;

                                if (threadId != null) {
                                   Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => AdminChatScreen(initialThreadId: threadId)),
                                   );
                                } else {
                                   ToastUtils.show(context, "Failed to initiate chat session.", type: ToastType.error);
                                }
                              },
                            ),
                            const SizedBox(width: 15),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent.withOpacity(0.2),
                                foregroundColor: Colors.redAccent,
                                elevation: 0,
                                side: const BorderSide(color: Colors.redAccent)
                              ),
                              icon: const Icon(Icons.person_remove),
                              label: const Text("DELETE"),
                              onPressed: () => _showDeleteConfirm(context),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),

               const SizedBox(height: 20),
               
               // 2. Stats
               Row(
                 children: [
                   Expanded(child: _buildStatCard("Total Orders", "${_orders.length}")),
                   const SizedBox(width: 15),
                   Expanded(child: _buildStatCard("Total Spent", "₦${totalSpent.toStringAsFixed(0)}")),
                 ],
               ),

               const SizedBox(height: 20),
               const Align(alignment: Alignment.centerLeft, child: Text("Recent Orders", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
               const SizedBox(height: 10),

               // 3. Orders List
               if (_isLoading)
                 const Center(child: CircularProgressIndicator())
               else if (_orders.isEmpty)
                 const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No orders yet", style: TextStyle(color: Colors.white54))))
               else
                 ..._orders.map((order) => Padding(
                   padding: const EdgeInsets.only(bottom: 10),
                   child: GestureDetector(
                     onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminOrderDetailScreen(order: order))),
                     child: GlassContainer(
                       opacity: 0.1,
                       padding: const EdgeInsets.all(15),
                       child: Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Text("Order #${order.id.substring(order.id.length-6).toUpperCase()}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                               Text(order.date.toString().substring(0, 16), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                             ],
                           ),
                           Container(
                             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                             decoration: BoxDecoration(
                               color: order.status == OrderStatus.Completed ? Colors.green.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                               borderRadius: BorderRadius.circular(8),
                             ),
                             child: Text(order.status.name, style: TextStyle(color: order.status == OrderStatus.Completed ? Colors.greenAccent : Colors.blueAccent, fontSize: 12)),
                           )
                         ],
                       ),
                     ),
                   ),
                 )),
             ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value) {
    return GlassContainer(
      opacity: 0.1,
      padding: const EdgeInsets.all(15),
      child: Column(
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(color: AppTheme.secondaryColor, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
