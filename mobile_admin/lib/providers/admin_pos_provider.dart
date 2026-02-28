import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:clotheline_core/clotheline_core.dart';

class AdminPOSProvider extends ChangeNotifier {
  // Guest Info
  String? guestName;
  String? guestPhone;
  String? guestEmail;
  
  // Selection
  Branch? selectedBranch;
  final List<CartItem> laundryItems = [];
  final List<StoreCartItem> storeItems = [];
  
  // Payment & Logistics
  String paymentMethod = 'cash'; // cash, pos, transfer, pay_on_delivery
  String pickupOption = 'Dropoff'; // For POS, usually 'Dropoff' (they brought it)
  String deliveryOption = 'Pickup'; // Usually 'Pickup' (they'll come back)
  
  double deliveryFee = 0;
  String? deliveryAddress;
  String? laundryNotes;
  
  bool isSaving = false;
  
  // Offline Sync
  int offlineOrderCount = 0;
  bool isSyncing = false;
  
  AdminPOSProvider() {
    _loadOfflineCount();
  }

  Future<void> _loadOfflineCount() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> queue = prefs.getStringList('offline_orders') ?? [];
    offlineOrderCount = queue.length;
    notifyListeners();
  }

  Future<void> syncOfflineOrders() async {
    if (isSyncing || offlineOrderCount == 0) return;
    isSyncing = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> queue = prefs.getStringList('offline_orders') ?? [];
      
      final api = ApiService();
      List<String> remainingQueue = [];
      
      for (String orderJson in queue) {
        try {
          final Map<String, dynamic> data = jsonDecode(orderJson);
          // Only send the payload to the server
          final response = await api.client.post('/orders', data: data);
          if (response.statusCode != 200 && response.statusCode != 201) {
            remainingQueue.add(orderJson); // keep if failed
          }
        } catch (e) {
          remainingQueue.add(orderJson); // keep if failed
        }
      }
      
      await prefs.setStringList('offline_orders', remainingQueue);
      offlineOrderCount = remainingQueue.length;
    } catch (e) {
      debugPrint("Offline Sync Error: $e");
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

  void setBranch(Branch branch) {
    selectedBranch = branch;
    laundryItems.clear();
    storeItems.clear();
    notifyListeners();
  }

  void setGuestInfo({String? name, String? phone, String? email}) {
    guestName = name;
    guestPhone = phone;
    guestEmail = email;
    notifyListeners();
  }

  void addLaundryItem(CartItem item) {
    laundryItems.add(item);
    notifyListeners();
  }

  void addStoreItem(StoreCartItem item) {
    final index = storeItems.indexWhere((i) => i.product.id == item.product.id && i.variant?.id == item.variant?.id);
    if (index != -1) {
      final old = storeItems[index];
      storeItems[index] = StoreCartItem(product: item.product, variant: item.variant, quantity: old.quantity + item.quantity);
    } else {
      storeItems.add(item);
    }
    notifyListeners();
  }

  void removeLaundryItem(CartItem item) {
    laundryItems.remove(item);
    notifyListeners();
  }

  void removeStoreItem(StoreCartItem item) {
    storeItems.remove(item);
    notifyListeners();
  }

  // [NEW] Category Isolation
  void clearAllItems() {
    laundryItems.clear();
    storeItems.clear();
    deliveryFee = 0;
    notifyListeners();
  }

  // Totals
  double get subtotal => laundryItems.fold(0.0, (sum, i) => sum + i.checkoutPrice) + 
                         storeItems.fold(0.0, (sum, i) => sum + i.totalPrice);
  
  double get totalAmount => subtotal + deliveryFee;

  void reset() {
    guestName = null;
    guestPhone = null;
    guestEmail = null;
    selectedBranch = null;
    laundryItems.clear();
    storeItems.clear();
    paymentMethod = 'cash';
    deliveryFee = 0;
    deliveryAddress = null;
    laundryNotes = null;
    isSaving = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> createOrder() async {
    if (selectedBranch == null) return {'success': false, 'message': 'Select a branch'};
    if (laundryItems.isEmpty && storeItems.isEmpty) return {'success': false, 'message': 'Bucket is empty'};
    
    isSaving = true;
    notifyListeners();

    try {
      final api = ApiService();
      
      final itemsData = [
        ...laundryItems.map((i) => {
          'itemType': 'Service',
          'itemId': i.item.id,
          'name': i.item.name,
          'serviceType': i.serviceType?.name ?? 'Generic Service',
          'quantity': i.quantity,
          'price': i.totalPrice / i.quantity,
        }),
        ...storeItems.map((i) => {
          'itemType': 'Product',
          'itemId': i.product.id,
          'name': i.product.name,
          'variant': i.variant?.name,
          'quantity': i.quantity,
          'price': i.totalPrice / i.quantity,
        }),
      ];

      final orderData = {
        'branchId': selectedBranch!.id,
        'isWalkIn': true,
        'fulfillmentMode': laundryItems.isNotEmpty ? laundryItems.first.fulfillmentMode : 'logistics',
        'quoteRequired': laundryItems.any((i) => i.quoteRequired),
        'inspectionFee': laundryItems.isNotEmpty ? laundryItems.first.inspectionFee : 0, 
        'guestInfo': {
          'name': guestName,
          'phone': guestPhone,
          'email': guestEmail,
        },
        'items': itemsData,
        'subtotal': subtotal,
        'deliveryFee': deliveryFee,
        'totalAmount': totalAmount,
        'paymentMethod': paymentMethod,
        'paymentStatus': paymentMethod == 'pay_on_delivery' ? 'Pending' : 'Paid',
        'pickupOption': pickupOption,
        'deliveryOption': deliveryOption,
        'deliveryAddress': deliveryAddress,
        'deliveryPhone': guestPhone,
        'laundryNotes': laundryNotes,
      };

      // Offline Check
      final connectivityResult = await Connectivity().checkConnectivity();
      bool hasConnection = false;
      if (connectivityResult is List) {
         hasConnection = !connectivityResult.contains(ConnectivityResult.none);
      } else {
         hasConnection = connectivityResult != ConnectivityResult.none;
      }

      if (!hasConnection) {
        // Enqueue Offline
        final prefs = await SharedPreferences.getInstance();
        List<String> queue = prefs.getStringList('offline_orders') ?? [];
        queue.add(jsonEncode(orderData));
        await prefs.setStringList('offline_orders', queue);
        offlineOrderCount = queue.length;
        
        isSaving = false;
        notifyListeners();
        
        // Return dummy success identifying it was saved offline
        // Generate a random ID to satisfy ui popup requirements
        final dummyId = 'OFFLINE_${DateTime.now().millisecondsSinceEpoch}';
        
        return {
          'success': true, 
          'isOffline': true,
          'order': {
             '_id': dummyId,
             ...orderData
          }
        };
      }

      final response = await api.client.post('/orders', data: orderData);
      
      isSaving = false;
      notifyListeners();
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'isOffline': false, 'order': response.data};
      } else {
        return {'success': false, 'message': response.data['msg'] ?? 'Failed to create order'};
      }
    } catch (e) {
      isSaving = false;
      notifyListeners();
      return {'success': false, 'message': e.toString()};
    }
  }
}
