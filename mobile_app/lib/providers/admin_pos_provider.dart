import 'package:flutter/material.dart';
import '../models/booking_models.dart';
import '../models/store_product.dart';
import '../models/branch_model.dart';
import '../services/api_service.dart';

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
  
  bool isSaving = false;

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

  // Totals
  double get subtotal => laundryItems.fold(0.0, (sum, i) => sum + i.totalPrice) + 
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
          'serviceType': i.serviceType.name,
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
      };

      final response = await api.client.post('/orders', data: orderData);
      
      isSaving = false;
      notifyListeners();
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'order': response.data};
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
