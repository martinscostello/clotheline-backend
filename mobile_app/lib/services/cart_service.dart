import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/booking_models.dart';
import '../models/store_product.dart';
import 'api_service.dart';
import 'package:latlong2/latlong.dart';

// Simple Singleton Service for Cart Persistence
class CartService extends ChangeNotifier {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;


  final List<CartItem> _items = [];
  final List<StoreCartItem> _storeItems = []; // [NEW] Store items

  List<CartItem> get items => List.unmodifiable(_items);
  List<StoreCartItem> get storeItems => List.unmodifiable(_storeItems);
  
  double get storeTotalAmount => _storeItems.fold(0, (sum, item) => sum + item.totalPrice);
  double get serviceTotalAmount => _items.fold(0, (sum, item) => sum + item.totalPrice);
  double _taxRate = 7.5;
  bool _taxEnabled = true;

  double get taxRate => _taxEnabled ? _taxRate : 0.0;
  


  CartService._internal() {
    _loadCart();
    fetchTaxSettings();
  }

  Future<void> _loadCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load Laundry Items
      final String? laundryJson = prefs.getString('cart_items');
      if (laundryJson != null) {
        final List<dynamic> decoded = json.decode(laundryJson);
        _items.clear();
        _items.addAll(decoded.map((e) => CartItem.fromJson(e)).toList());
      }

      // Load Store Items
      final String? storeJson = prefs.getString('store_items');
      if (storeJson != null) {
         final List<dynamic> decoded = json.decode(storeJson);
         _storeItems.clear();
         _storeItems.addAll(decoded.map((e) => StoreCartItem.fromJson(e)).toList());
      }

      // Load Branch Context
      _activeBranchId = prefs.getString('cart_branch_id');
      
      notifyListeners();
    } catch (e) {
      print("Error loading cart: $e");
    }
  }

  Future<void> _saveCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save Laundry Items
      final String laundryJson = json.encode(_items.map((e) => e.toJson()).toList());
      await prefs.setString('cart_items', laundryJson);

      // Save Store Items
      final String storeJson = json.encode(_storeItems.map((e) => e.toJson()).toList());
      await prefs.setString('store_items', storeJson);

      // Save Branch Context
      if (_activeBranchId != null) {
        await prefs.setString('cart_branch_id', _activeBranchId!);
      } else {
        await prefs.remove('cart_branch_id');
      }
    } catch (e) {
       print("Error saving cart: $e");
    }
  }

  Future<void> fetchTaxSettings() async {
    try {
      // Lazy import to avoid circular dep if any (ApiService is safe)
      final ApiService api = ApiService(); 
      final response = await api.client.get('/settings');
      if (response.data != null) {
        _taxEnabled = response.data['taxEnabled'] ?? true;
        double rate = (response.data['taxRate'] ?? 7.5).toDouble();
        // [FIX] Safety Cap - Never trust a tax rate > 50%
        if (rate > 50) rate = 7.5;
        _taxRate = rate;
        notifyListeners();
      }
    } catch (e) {
      print("Error fetching tax settings: $e");
    }
  }

  void addItem(CartItem item) {
    _items.add(item);
    _saveCart();
    notifyListeners();
  }
  
  void addStoreItem(StoreCartItem item) {
    // Check global stock limit
    if (item.product.stockLevel <= 0) return;

    final index = _storeItems.indexWhere((i) => i.product.id == item.product.id && i.variant?.id == item.variant?.id);
    int currentQty = index != -1 ? _storeItems[index].quantity : 0;
    
    if (currentQty + item.quantity > item.product.stockLevel) {
       // Cannot add more than stock. 
       // We can only add the remainder
       int remainder = item.product.stockLevel - currentQty;
       if (remainder > 0) {
         if (index != -1) {
             _storeItems[index] = StoreCartItem(product: item.product, variant: item.variant, quantity: currentQty + remainder);
         } else {
             _storeItems.add(StoreCartItem(product: item.product, variant: item.variant, quantity: remainder));
         }
         _saveCart();
         notifyListeners();
       }
       return; 
    }

    if (index != -1) {
       final old = _storeItems[index];
       _storeItems[index] = StoreCartItem(product: item.product, variant: item.variant, quantity: old.quantity + item.quantity);
    } else {
      _storeItems.add(item);
    }
    _saveCart();
    notifyListeners();
  }
  
  void updateStoreItemQuantity(StoreCartItem item, int newQuantity) {
    if (newQuantity > item.product.stockLevel) {
       newQuantity = item.product.stockLevel; // Cap at max
    }

    final index = _storeItems.indexOf(item);
    if (index != -1) {
      if (newQuantity <= 0) {
        _storeItems.removeAt(index);
      } else {
        _storeItems[index] = StoreCartItem(product: item.product, variant: item.variant, quantity: newQuantity);
      }
      _saveCart();
      notifyListeners();
    }
  }

  void removeItem(CartItem item) {
    _items.remove(item);
    _saveCart();
    notifyListeners();
  }
  
  void removeStoreItem(StoreCartItem item) {
    _storeItems.remove(item);
    _saveCart();
    notifyListeners();
  }

  // Branch Context
  String? _activeBranchId;
  String? get activeBranchId => _activeBranchId;

  // Global Location Context
  LatLng? _deliveryLocation;
  LatLng? get deliveryLocation => _deliveryLocation;
  
  void setDeliveryLocation(LatLng? location) {
    _deliveryLocation = location;
    notifyListeners();
  }

  // Fulfillment Modes Check
  Set<String> get activeModes {
    final modes = _items.map((item) => item.fulfillmentMode).toSet();
    if (_storeItems.isNotEmpty) {
      modes.add('logistics'); // Products always follow logistics mode
    }
    return modes;
  }

  bool get hasFulfillmentConflict => activeModes.length > 1;

  // Returns true if valid to switch, false if cart needs clearing confirmation
  bool validateBranch(String newBranchId) {
    if (_activeBranchId == null) return true; // First load
    if (_items.isEmpty && _storeItems.isEmpty) return true; // Empty cart is safe
    if (_activeBranchId == newBranchId) return true; // Same branch
    return false; // Mismatch with items in cart
  }

  // Promotions
  Map<String, dynamic>? _appliedPromotion;
  Map<String, dynamic>? get appliedPromotion => _appliedPromotion;

  // Aggregated Service Discounts (Internal Service Discounts)
  Map<String, double> get serviceDiscounts {
    Map<String, double> discounts = {};
    for (var item in _items) {
      if (item.discountPercentage > 0) {
         double itemDiscount = item.baseTotal * (item.discountPercentage / 100);
         
         String key = "Discount (${item.serviceType?.name ?? 'Generic'})";
         discounts[key] = (discounts[key] ?? 0) + itemDiscount;
      }
    }
    return discounts;
  }
  
  double get serviceTotalDiscount => serviceDiscounts.values.fold(0, (sum, v) => sum + v);

  // [NEW] Gross Subtotal (Before any discounts)
  double get serviceGrossSubtotal => _items.fold(0, (sum, item) => sum + item.baseTotal);
  
  // Store Promo (Applied Code)
  double get storeDiscountAmount {
    if (_appliedPromotion == null) return 0.0;
    
    final type = _appliedPromotion!['type'];
    final value = (_appliedPromotion!['value'] as num).toDouble();
    final maxDiscount = _appliedPromotion!['maxDiscountAmount'] != null ? (_appliedPromotion!['maxDiscountAmount'] as num).toDouble() : null;
    
    // Apply only to STORE items
    double baseStoreTotal = storeTotalAmount; 
    double discount = 0.0;

    if (type == 'fixed') {
      discount = value;
    } else if (type == 'percentage') {
       discount = (baseStoreTotal * value) / 100;
       
       if (value >= 100) {
          discount = baseStoreTotal;
       }
       if (maxDiscount != null && discount > maxDiscount) {
         discount = maxDiscount;
       }
    }
    
    return discount > baseStoreTotal ? baseStoreTotal : discount;
  }

  // Gross Subtotals (Before Store Items)
  // [NEW] servicePayableSubtotal = Sum of CartItem.totalPrice 
  // For Laundry this is Gross. For Deployment this is Inspection Fee.
  double get servicePayableSubtotal => _items.fold(0, (sum, item) => sum + item.totalPrice);

  // [NEW] Helper to check if any item is pending a quote
  bool get hasPendingQuote => _items.any((item) => item.quoteRequired && deliveryLocation == null);
  
  // [NEW] serviceEstimateSubtotal = Sum of CartItem.fullEstimate (Net)
  double get serviceEstimateSubtotal => _items.fold(0, (sum, item) => sum + item.fullEstimate);
  
  // Total of all discounts (Service Internal + Store Promo)
  double get discountAmount => storeDiscountAmount + serviceTotalDiscount; 

  // Base Subtotal (PAYABLE) = Gross Service + Gross Store
  double get subtotal => servicePayableSubtotal + storeTotalAmount; 
  
  // Net Total (PAYABLE)
  double get subtotalAfterDiscount => (subtotal - discountAmount) < 0 ? 0 : (subtotal - discountAmount);
  
  // Tax Calculations (PAYABLE)
  // [FIX] Don't apply VAT to Inspection Fees (Deployment mode with Pending Quote)
  double get taxAmount {
     if (activeModes.contains('deployment') && _items.any((i) => i.quoteRequired)) {
       // Inspection fees are flat (no tax)
       return 0.0;
     }
     return (subtotalAfterDiscount * (taxRate / 100));
  }
  
  // Final Total (Payable Now)
  double get totalAmount {
    return subtotalAfterDiscount + taxAmount;
  }

  // Split Tax (Approximate for display of PAYABLE tax)
  double get serviceTaxAmount {
    if (subtotalAfterDiscount == 0) return 0.0;
    if (taxAmount == 0) return 0.0;
    
    double serviceNet = servicePayableSubtotal - serviceTotalDiscount;
    if (serviceNet < 0) serviceNet = 0;
    
    return (serviceNet / subtotalAfterDiscount) * taxAmount;
  }

  // Tax on estimate (for display)
  // [FIX] Total Estimate = (Gross - Discount) + VAT
  double get serviceEstimateGross => serviceGrossSubtotal;
  double get serviceEstimateNet => serviceGrossSubtotal - serviceTotalDiscount;
  double get serviceEstimateTaxAmount => serviceEstimateNet * (taxRate / 100);
  double get serviceEstimateTotalAmount => serviceEstimateNet + serviceEstimateTaxAmount;

  double get storeTaxAmount {
     if (subtotalAfterDiscount == 0) return 0.0;
     double storeNet = storeTotalAmount - storeDiscountAmount;
     if (storeNet < 0) storeNet = 0;
     
     return (storeNet / subtotalAfterDiscount) * taxAmount;
  }
  
  // Apply Promo
  Future<String?> applyPromoCode(String code) async {
    if (_activeBranchId == null) return "Please select a branch first";
    
    try {
      final ApiService api = ApiService();
      // Send cartTotal so backend can check Min Spend initially
      final response = await api.client.post('/promotions/validate', data: {
        'code': code.trim().toUpperCase(),
        'branchId': _activeBranchId,
        'orderTotal': subtotal // Use current subtotal
      });

      if (response.statusCode == 200 && response.data['valid'] == true) {
         _appliedPromotion = response.data;
         notifyListeners();
         return null; // Success
      } else {
        return response.data['msg'] ?? "Invalid code";
      }
    } catch (e) {
      // Dio Error Parsing
      if (e.toString().contains("400") || e.toString().contains("404")) {
          // If possible, parse detailed message from response via Interceptor?
          // ApiService logs it.
          // For now generic or "Invalid".
          return "Invalid or expired promotion";
      }
      return "Error validating code";
    }
  }

  void removePromo() {
    _appliedPromotion = null;
    notifyListeners();
  }

  // --- Update Clear Methods to wipe promo ---

  void clearCart() {
    _items.clear();
    _storeItems.clear();
    _appliedPromotion = null; // Clear Promo
    _saveCart(); // Save emptiness
    notifyListeners();
  }

  // When branch updates
  void setBranch(String branchId) {
    if (_activeBranchId != branchId) {
       _appliedPromotion = null; // Clear promo on branch switch
    }
    _activeBranchId = branchId;
    _saveCart();
  }

  void clearServiceItems() {
    _items.clear();
    _saveCart();
    notifyListeners();
  }

  void clearStoreItems() {
    _storeItems.clear();
    _saveCart();
    notifyListeners();
  }
}
