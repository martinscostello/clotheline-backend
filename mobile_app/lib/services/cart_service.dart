import 'package:flutter/material.dart';
import '../models/booking_models.dart';
import '../models/store_product.dart';

// Simple Singleton Service for Cart Persistence
class CartService extends ChangeNotifier {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  final List<CartItem> _items = [];
  final List<StoreCartItem> _storeItems = []; // [NEW] Store items

  List<CartItem> get items => List.unmodifiable(_items);
  List<StoreCartItem> get storeItems => List.unmodifiable(_storeItems);
  
  double get storeTotalAmount => _storeItems.fold(0, (sum, item) => sum + item.totalPrice);
  double get serviceTotalAmount => _items.fold(0, (sum, item) => sum + item.totalPrice);

  double get totalAmount => serviceTotalAmount + storeTotalAmount;

  void addItem(CartItem item) {
    _items.add(item);
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
      notifyListeners();
    }
  }

  void removeItem(CartItem item) {
    _items.remove(item);
    notifyListeners();
  }
  
  void removeStoreItem(StoreCartItem item) {
    _storeItems.remove(item);
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    _storeItems.clear();
    notifyListeners();
  }
}
