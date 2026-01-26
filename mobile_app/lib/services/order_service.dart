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
        // Enforce Descending Sort (Newest First)
        _orders.sort((a, b) => b.date.compareTo(a.date));
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error fetching orders: $e");
    }
  }

  // Fetch Single Order (Deep Link Support)
  Future<OrderModel?> getOrderById(String id) async {
    try {
      // Check local cache first
      try {
        return _orders.firstWhere((o) => o.id == id);
      } catch (_) {}

      // Fetch from API
      final response = await _apiService.client.get('/orders/$id');
      if (response.statusCode == 200) {
        return OrderModel.fromJson(response.data);
      }
    } catch (e) {
      debugPrint("Error fetching order $id: $e");
    }
    return null;
  }

  // [NEW] Fetch Orders for specific User (Admin View)
  Future<List<OrderModel>> fetchOrdersByUser(String userId) async {
    try {
      final response = await _apiService.client.get('/orders/user/$userId');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => OrderModel.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint("Error fetching user orders: $e");
    }
    return [];
  }

  // For User: Create Order
  Future<Map<String, dynamic>?> createOrder(Map<String, dynamic> orderData) async {
    try {
      final response = await _apiService.client.post('/orders', data: orderData);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
      return null;
    } catch (e) {
      debugPrint("Error creating order: $e");
      return null;
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

  // [NEW] Report Exception
  Future<bool> updateExceptionStatus(String id, OrderExceptionStatus status, String? note) async {
    try {
      final response = await _apiService.client.put('/orders/$id/exception', data: {
        'exceptionStatus': status.name,
        'exceptionNote': note
      });
      if (response.statusCode == 200) {
         await fetchOrders(); 
         return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error updating exception: $e");
      return false;
    }
  }

  // [NEW] Batch Update Status
  Future<bool> batchUpdateStatus(List<String> ids, String status) async {
    try {
      final response = await _apiService.client.post('/orders/batch-status', data: {
        'orderIds': ids,
        'status': status
      });
      if (response.statusCode == 200) {
         await fetchOrders(); 
         return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error batch updating: $e");
      return false;
    }
  }
  // [NEW] Override Delivery Fee (Admin)
  Future<bool> overrideDeliveryFee(String id, double fee) async {
    try {
      final response = await _apiService.client.put('/orders/$id/override-fee', data: {'fee': fee});
      if (response.statusCode == 200) {
        await fetchOrders(); 
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error overriding fee: $e");
      return false;
    }
  }

  // [NEW] Confirm Fee Adjustment (User)
  Future<bool> confirmFeeAdjustment(String id, String choice) async {
    try {
      final response = await _apiService.client.put('/orders/$id/confirm-fee', data: {'choice': choice});
      if (response.statusCode == 200) {
        await fetchOrders(); 
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error confirming fee: $e");
      return false;
    }
  }
}
