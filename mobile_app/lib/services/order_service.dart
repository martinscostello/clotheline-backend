import 'package:flutter/foundation.dart';
import 'package:laundry_app/services/api_service.dart';
import '../models/order_model.dart';

class OrderService extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<OrderModel> _orders = [];
  List<OrderModel> get orders => List.unmodifiable(_orders);

  // For Admin: Fetch all orders
  Future<void> fetchOrders() async {
    try {
      final response = await _apiService.client.get('/orders');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _orders = data.map((json) => OrderModel.fromJson(json)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error fetching orders: $e");
    }
  }

  // For User: Create Order
  Future<bool> createOrder(Map<String, dynamic> orderData) async {
    try {
      final response = await _apiService.client.post('/orders', data: orderData);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Error creating order: $e");
      return false;
    }
  }

  // For Admin: Update Status
  Future<bool> updateStatus(String id, String status) async {
    try {
      final response = await _apiService.client.put('/orders/$id/status', data: {'status': status});
      if (response.statusCode == 200) {
        final index = _orders.indexWhere((o) => o.id == id);
        if (index != -1) {
          // Optimistic local update? Or refetch.
          // Let's refetch to be safe, or just update local list
          // Re-fetch is safer for consistency
          await fetchOrders(); 
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error updating status: $e");
      return false;
    }
  }
}
