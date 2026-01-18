import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/booking_models.dart';
import '../models/store_product.dart';
import 'api_service.dart';

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
    _fetchTaxSettings();
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

  Future<void> _fetchTaxSettings() async {
    try {
      // Lazy import to avoid circular dep if any (ApiService is safe)
      final ApiService api = ApiService(); 
      final response = await api.client.get('/settings');
      if (response.data != null) {
        _taxEnabled = response.data['taxEnabled'] ?? true;
        _taxRate = (response.data['taxRate'] ?? 7.5).toDouble();
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
    // Check if same item/variant exists
    final index = _storeItems.indexWhere((i) => i.product.id == item.product.id && i.variant?.id == item.variant?.id);
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

  double get discountAmount {
    if (_appliedPromotion == null) return 0.0;
    
    // Backend returns the exact discount amount in validation, but we can also limit it here if we trust the object
    // For simplicity, let's use the object returned by the validate endpoint which should contain 'discountAmount'
    // relative to the subtotal sent. However, if subtotal changes (items added), we technically need to RE-VALIDATE or RE-CALCULATE.
    
    // Strategy: We will recalculate locally based on the rules if simple, OR just store the fixed value if it was fixed.
    // Better Strategy: Recalculate based on type.
    
    final type = _appliedPromotion!['type'];
    final value = (_appliedPromotion!['value'] as num).toDouble();
    
    if (type == 'fixed') {
      return value > subtotal ? subtotal : value;
    } else if (type == 'percentage') {
       double discount = (subtotal * value) / 100;
       // Check for max discount if we had that field, assuming backend validation handled capped logic for the initial check.
       // Ideally we should re-verify with backend on checkout, but for UI:
       return discount;
    }
    return 0.0;
  }

  // Base Subtotal (Before Discount)
  double get subtotal => serviceTotalAmount + storeTotalAmount; 
  double get subtotalAfterDiscount => (subtotal - discountAmount) < 0 ? 0 : (subtotal - discountAmount);
  
  // Tax Calculations
  double get taxAmount => (subtotalAfterDiscount * (taxRate / 100)); // Combined Tax
  
  // Granular Tax (assuming discount applies proportionally or to total? implementation varies, assuming discount is general)
  // For granular display, if we ignore discount splitting for now:
  double get storeTaxAmount => (storeTotalAmount * (taxRate / 100));
  double get serviceTaxAmount => (serviceTotalAmount * (taxRate / 100));

  double get totalAmount => subtotalAfterDiscount + taxAmount;

  // Apply Promo
  Future<String?> applyPromoCode(String code) async {
    if (_activeBranchId == null) return "Please select a branch first";
    
    try {
      final ApiService api = ApiService();
      final response = await api.client.post('/promotions/validate', data: {
        'code': code,
        'branchId': _activeBranchId,
        'cartTotal': subtotal
      });

      if (response.statusCode == 200 && response.data['isValid'] == true) {
         _appliedPromotion = response.data;
         notifyListeners();
         return null; // Success
      } else {
        return response.data['message'] ?? "Invalid code";
      }
    } catch (e) {
      if (e.toString().contains("400") || e.toString().contains("404")) {
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
