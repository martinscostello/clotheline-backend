import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'package:dio/dio.dart';
import '../models/order_model.dart';

class OrderService extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<OrderModel> _orders = [];
  List<OrderModel> get orders => List.unmodifiable(_orders);

  // Fetch orders based on role
  Future<void> fetchOrders({String role = 'user'}) async {
    try {
      final endpoint = role == 'admin' ? '/orders' : '/orders/me';
      final response = await _apiService.client.get(endpoint);
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
          await fetchOrders(role: 'admin'); 
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
         await fetchOrders(role: 'admin'); 
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
         await fetchOrders(role: 'admin'); 
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
        await fetchOrders(role: 'admin'); 
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
        await fetchOrders(role: 'user'); 
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error confirming fee: $e");
      return false;
    }
  }
  // [NEW] Despatch Order (Admin)
  Future<bool> despatchOrder(String id) async {
    try {
      final response = await _apiService.client.put('/orders/$id/despatch');
      if (response.statusCode == 200) {
        await fetchOrders(role: 'admin');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error despatching order: $e");
      return false;
    }
  }

  // [NEW] Adjust Pricing (Admin)
  Future<String?> adjustPricing(String id, double newPrice, String? notes) async {
    try {
      final response = await _apiService.client.put('/orders/$id/adjust-pricing', data: {
        'newPrice': newPrice,
        'notes': notes
      });
      if (response.statusCode == 200) {
        await fetchOrders(role: 'admin');
        return null; // Success!
      }
      return response.data['msg'] ?? "Unexpected response from server";
    } catch (e) {
      debugPrint("Error adjusting pricing: $e");
      if (e is DioException) {
        return e.response?.data['msg'] ?? e.message;
      }
      return e.toString();
    }
  }

  // [NEW] Trigger Payment Notification (Admin)
  Future<bool> triggerPaymentNotification(String id) async {
    try {
      final response = await _apiService.client.post('/orders/$id/trigger-payment');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Error triggering payment: $e");
      return false;
    }
  }

  // [NEW] Convert Order to Deployment (Admin)
  Future<bool> convertToDeployment(String id) async {
    try {
      final response = await _apiService.client.put('/orders/$id/convert-to-deployment');
      if (response.statusCode == 200) {
        await fetchOrders(role: 'admin');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error converting order: $e");
      return false;
    }
  }

  // [NEW] Mark as Paid (Admin)
  Future<bool> markAsPaid(String id, String method, {String? reference}) async {
    try {
      final response = await _apiService.client.put('/orders/$id/mark-as-paid', data: {
        'method': method,
        'reference': reference
      });
      if (response.statusCode == 200) {
        await fetchOrders(role: 'admin');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error marking as paid: $e");
      return false;
    }
  }
}
